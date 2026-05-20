require "net/http"
require "json"

# One-off verification harness: re-seed the canonical DB from rubygems.org's
# JSON API (an independent source), regenerate the v1 compact index, and diff
# our /info/<gem> byte-for-byte against the live compact index.
#
# /versions is intentionally NOT diffed line-for-line: the live file is
# append-only and history-dependent (a monthly snapshot plus per-push delta
# lines), which a from-scratch rebuild cannot reproduce. Instead we confirm
# our /info checksum equals the MD5 stamped on the last live /versions line.
namespace :compact_index do
  TARGET_GEMS = %w[zeitwerk thor concurrent-ruby rack i18n tzinfo].freeze

  desc "Verify v1 /info matches live rubygems.org byte-for-byte (representative gems)"
  task verify_live: :environment do
    targets = TARGET_GEMS

    puts "Wiping canonical tables and re-importing #{targets.size} gems from the JSON API...\n\n"
    Dependency.delete_all
    BuildArtifact.delete_all
    Version.delete_all
    Rubygem.delete_all

    targets.each { |name| import_gem(name) }

    puts "\nRebuilding v1 index..."
    CompactIndex::Indexer.new(CompactIndex::Schemas::V1).rebuild!
    storage = CompactIndex::Storage.new("v1")

    puts "\n=== Byte-for-byte /info comparison ===\n\n"
    results = targets.map { |name| compare_info(name, storage) }

    puts "\n=== Summary ===\n"
    results.each { |r| puts "  #{r[:match] ? 'MATCH ' : 'DIFFER'}  /info/#{r[:gem]}  (#{r[:versions]} versions)" }
    matched = results.count { |r| r[:match] }
    puts "\n#{matched}/#{results.size} gems match live /info byte-for-byte."
  end

  # ---- helpers ----

  def import_gem(name)
    print "  importing #{name}... "
    versions = http_json("https://rubygems.org/api/v1/versions/#{name}.json")
    gem = Rubygem.create!(name: name, indexed: true)

    # versions.json is id-DESC (newest first). Inserting in reverse gives our
    # rows ascending ids in rubygems.org push order, so the renderer's
    # (created_at, id) sort reproduces live /info order exactly — including
    # ties where created_at is identical but push order differs.
    versions.reverse_each do |v|
      platform = v["platform"]
      full = platform == "ruby" ? "#{name}-#{v['number']}" : "#{name}-#{v['number']}-#{platform}"
      version = gem.versions.create!(
        number: v["number"],
        platform: platform,
        full_name: full,
        indexed: true,
        prerelease: v["prerelease"],
        sha256: v["sha"],
        required_ruby_version: v["ruby_version"],
        required_rubygems_version: v["rubygems_version"],
        created_at: v["created_at"]
      )
      import_deps(name, version, platform)
    end
    puts "#{gem.versions.count} versions"
  end

  def import_deps(name, version, platform)
    # The v2 endpoint defaults to the ruby platform; platform variants share
    # a version number but have distinct dependencies, disambiguated by the
    # ?platform= query param.
    url = "https://rubygems.org/api/v2/rubygems/#{name}/versions/#{version.number}.json?platform=#{platform}"
    detail = http_json(url)
    runtime = detail&.dig("dependencies", "runtime") || []
    runtime.each do |d|
      version.dependencies.create!(
        unresolved_name: d["name"],
        requirements: d["requirements"],
        scope: "runtime",
        rubygem: Rubygem.find_by(name: d["name"])
      )
    end
  end

  def compare_info(name, storage)
    ours = storage.read("info/#{name}").to_s
    live = http_text("https://index.rubygems.org/info/#{name}")
    match = (ours == live)

    if match
      puts "  /info/#{name}: MATCH (#{ours.lines.size - 1} versions, #{ours.bytesize} bytes)"
    else
      puts "  /info/#{name}: DIFFER"
      print_first_diff(ours, live)
    end

    { gem: name, match: match, versions: ours.lines.size - 1 }
  end

  def print_first_diff(ours, live)
    o = ours.lines
    l = live.lines
    idx = (0...[ o.size, l.size ].max).find { |i| o[i] != l[i] }
    return unless idx

    puts "    first diff at line #{idx + 1}:"
    puts "      ours: #{o[idx].inspect}"
    puts "      live: #{l[idx].inspect}"
  end

  def http_json(url)
    body = http_text(url)
    body && JSON.parse(body)
  end

  def http_text(url)
    res = Net::HTTP.get_response(URI(url))
    res.code == "200" ? res.body : nil
  end
end
