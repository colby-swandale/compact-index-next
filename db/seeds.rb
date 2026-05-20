# Idempotent seeds: a slice of the Rails gem family plus a few of its
# external runtime dependencies. Enough data to render meaningful
# /versions, /names, and /info/{gem} responses from the compact index.

RAILS_COMPONENTS = %w[
  activesupport
  activemodel
  activerecord
  actionpack
  actionview
  actionmailer
  actionmailbox
  actiontext
  activejob
  activestorage
  actioncable
  railties
].freeze

EXTERNAL_DEPS = %w[
  bundler
  rack
  nokogiri
  zeitwerk
  thor
  i18n
  tzinfo
  concurrent-ruby
  mail
  globalid
  rails-html-sanitizer
].freeze

ALL_GEM_NAMES = (%w[rails] + RAILS_COMPONENTS + EXTERNAL_DEPS).freeze

# 1. Gems
ALL_GEM_NAMES.each do |name|
  Rubygem.find_or_create_by!(name: name) { |g| g.indexed = true }
end

rails             = Rubygem.find_by!(name: "rails")
components        = RAILS_COMPONENTS.index_with { |n| Rubygem.find_by!(name: n) }
external          = EXTERNAL_DEPS.index_with { |n| Rubygem.find_by!(name: n) }

# 2. Versions — a small history per gem so the compact index has
# multiple entries to emit per /info/{gem} request.
RAILS_VERSIONS = %w[8.0.0 8.1.0 8.1.3].freeze

def upsert_version!(rubygem, number, platform: "ruby", prerelease: false)
  rubygem.versions.find_or_create_by!(number: number, platform: platform) do |v|
    v.full_name = "#{rubygem.name}-#{number}"
    v.gem_full_name = v.full_name
    v.gem_platform = platform
    v.canonical_number = number
    v.indexed = true
    v.prerelease = prerelease
    v.required_ruby_version = ">= 3.2.0"
    v.required_rubygems_version = ">= 3.5.0"
    v.sha256 = Digest::SHA256.hexdigest("#{rubygem.name}-#{number}-#{platform}")
    v.info_checksum = Digest::MD5.hexdigest("#{rubygem.name}-#{number}-info")
    v.metadata = { "homepage_uri" => "https://rubyonrails.org" }
  end
end

# Rails meta-gem + every component shares the same version numbers.
([ rails ] + components.values).each do |gem|
  RAILS_VERSIONS.each { |n| upsert_version!(gem, n) }
end

# External deps get one stable version each.
EXTERNAL_VERSIONS = {
  "bundler"              => "2.5.23",
  "rack"                 => "3.1.8",
  "nokogiri"             => "1.16.7",
  "zeitwerk"             => "2.6.18",
  "thor"                 => "1.3.2",
  "i18n"                 => "1.14.5",
  "tzinfo"               => "2.0.6",
  "concurrent-ruby"      => "1.3.4",
  "mail"                 => "2.8.1",
  "globalid"             => "1.2.1",
  "rails-html-sanitizer" => "1.6.0"
}.freeze

EXTERNAL_VERSIONS.each do |name, number|
  upsert_version!(external.fetch(name), number)
end

# 3. Dependencies — for each Rails component version, runtime-depend on
# activesupport at the same version; the rails meta-gem runtime-depends
# on every component. External deps wired in where they matter.
def add_dependency!(version, target_gem, requirements, scope: "runtime")
  version.dependencies.find_or_create_by!(
    unresolved_name: target_gem.name,
    scope: scope
  ) do |d|
    d.rubygem = target_gem
    d.requirements = requirements
  end
end

RAILS_VERSIONS.each do |number|
  req = "= #{number}"

  # rails -> every component at the same version
  rails_v = rails.versions.find_by!(number: number, platform: "ruby")
  components.each_value do |component|
    add_dependency!(rails_v, component, req)
  end
  add_dependency!(rails_v, external.fetch("bundler"), ">= 1.17.0")

  # each component (other than activesupport itself) -> activesupport
  activesupport = components.fetch("activesupport")
  components.each do |name, component|
    next if name == "activesupport"
    v = component.versions.find_by!(number: number, platform: "ruby")
    add_dependency!(v, activesupport, req)
  end

  # Targeted external deps for a few components
  actionpack_v   = components.fetch("actionpack").versions.find_by!(number: number, platform: "ruby")
  actionview_v   = components.fetch("actionview").versions.find_by!(number: number, platform: "ruby")
  actioncable_v  = components.fetch("actioncable").versions.find_by!(number: number, platform: "ruby")
  actionmailer_v = components.fetch("actionmailer").versions.find_by!(number: number, platform: "ruby")
  activesupport_v = activesupport.versions.find_by!(number: number, platform: "ruby")
  railties_v     = components.fetch("railties").versions.find_by!(number: number, platform: "ruby")

  add_dependency!(actionpack_v,   external.fetch("rack"), ">= 3.0")
  add_dependency!(actionview_v,   external.fetch("rails-html-sanitizer"), "~> 1.6")
  add_dependency!(actioncable_v,  external.fetch("nokogiri"), ">= 1.15")
  add_dependency!(actionmailer_v, external.fetch("mail"), "~> 2.8")
  add_dependency!(activesupport_v, external.fetch("i18n"), "~> 1.6")
  add_dependency!(activesupport_v, external.fetch("tzinfo"), "~> 2.0")
  add_dependency!(activesupport_v, external.fetch("concurrent-ruby"), "~> 1.0")
  add_dependency!(railties_v,     external.fetch("thor"), ">= 1.0")
  add_dependency!(railties_v,     external.fetch("zeitwerk"), "~> 2.6")
  add_dependency!(railties_v,     external.fetch("globalid"), ">= 0.3.6")
end

# 4. Build artifacts — fabricated pre-compiled native gem manifests for v3.
# Only attached to nokogiri (the canonical native-extension gem in this seed).
NATIVE_PLATFORMS = [
  [ "x86_64-linux-gnu",   "ruby32" ],
  [ "x86_64-linux-gnu",   "ruby33" ],
  [ "aarch64-linux-gnu",  "ruby33" ],
  [ "x86_64-darwin",      "ruby33" ],
  [ "arm64-darwin",       "ruby33" ]
].freeze

nokogiri_v = external.fetch("nokogiri").versions.find_by!(number: "1.16.7", platform: "ruby")
NATIVE_PLATFORMS.each do |platform, ruby_abi|
  sha = Digest::SHA256.hexdigest("nokogiri-1.16.7-#{platform}-#{ruby_abi}")
  BuildArtifact.find_or_create_by!(sha256: sha) do |a|
    a.version = nokogiri_v
    a.platform = platform
    a.ruby_abi = ruby_abi
    a.size = 8_000_000 + rand(2_000_000)
    a.source_url = "https://gems.example/nokogiri-1.16.7-#{platform}-#{ruby_abi}.gem"
  end
end

puts "Seeded #{Rubygem.count} gems, #{Version.count} versions, " \
     "#{Dependency.count} dependencies, #{BuildArtifact.count} build artifacts"
