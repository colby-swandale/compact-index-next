require "test_helper"

module CompactIndex
  # Asserts conformance to the published spec:
  # https://guides.rubygems.org/rubygems-org-compact-index-api/
  class ConformanceTest < ActiveSupport::TestCase
    test "multiple version constraints in a dependency are joined with '&' not ','" do
      # bundler 2.5.0 runtime-depends on rake ">= 2.4.0, < 3.0" (fixture)
      body = Schemas::V1.keyed_body_for(:info, "bundler")

      assert_includes body, "rake:>= 2.4.0&< 3.0",
        "intra-requirement constraints must use '&' (',' is the dependency delimiter)"
      refute_includes body, "rake:>= 2.4.0, < 3.0",
        "a literal ', ' would be misparsed as a second dependency"
    end

    test "multiple constraints in ruby/rubygems requirements also use '&'" do
      v = versions(:bundler_2_5_0)
      v.update_columns(required_ruby_version: ">= 2.7, < 3.3.dev")

      body = Schemas::V1.keyed_body_for(:info, "bundler")
      assert_includes body, "ruby:>= 2.7&< 3.3.dev"
    end

    test "/info line layout is VERSION DEPS|REQS with checksum present" do
      v = versions(:bundler_2_5_0)
      v.update_columns(sha256: "d" * 64)
      body = Schemas::V1.keyed_body_for(:info, "bundler")

      line = body.lines.find { |l| l.start_with?("2.5.0 ") }
      assert_match(/\A2\.5\.0 .+\|.*checksum:#{'d' * 64}/, line)
    end

    test "/versions lists yanked versions in natural order with a '-' prefix in place" do
      rake = rubygems(:rake)
      # Insert a yank chronologically between two live versions.
      rake.versions.create!(number: "13.2.0", platform: "ruby", full_name: "rake-13.2.0",
        indexed: false, yanked_at: Time.current, created_at: versions(:rake_13_2_1).created_at - 1.day)

      storage = Storage.new("v1")
      record = Schemas::V1.versions_record(rake, storage)

      assert_includes record[1], "-13.2.0", "yanked version must carry the '-' marker"
      # Natural order: the older yanked 13.2.0 should precede the newer live 13.2.1
      assert_operator record[1].index("-13.2.0"), :<, record[1].index("13.2.1")
    end

    test "/names is '---' followed by one gem name per line" do
      body = Schemas::V1.single_file_body_for(:names)
      assert_equal "---\n", body.lines.first
      assert(body.lines[1..].all? { |l| l.match?(/\A[^\s]+\n\z/) })
    end
  end
end
