require "test_helper"

module CompactIndex
  module Schemas
    class V1Test < ActiveSupport::TestCase
      test "renders /info/<gem> with checksum + ruby requirements but no created_at" do
        rake = rubygems(:rake)
        rake.versions.update_all(sha256: "deadbeef" * 8, required_ruby_version: ">= 3.0.0")

        body = V1.keyed_body_for(:info, "rake")

        assert_equal "---\n", body.lines.first
        assert_includes body, "13.2.1 bundler:>= 1.17|checksum:#{'deadbeef' * 8},ruby:>= 3.0.0"
        refute_includes body, "created_at:"
      end

      test "renders /names with one indexed gem per line" do
        body = V1.single_file_body_for(:names)

        assert_equal "---\n", body.lines.first
        assert_includes body, "rake\n"
        assert_includes body, "bundler\n"
      end

      test "versions_record returns [name, joined_versions, info_md5]" do
        rake = rubygems(:rake)
        storage = Storage.new("v1")
        record = V1.versions_record(rake, storage)

        assert_equal "rake", record[0]
        assert_equal "13.2.1", record[1]
        assert_equal 32, record[2].length # MD5 hex
      end

      test "versions_record checksum matches the materialized /info file" do
        rake = rubygems(:rake)
        Indexer.new(V1).rebuild!
        storage = Storage.new("v1")

        record = V1.versions_record(rake, storage)
        info_md5 = Digest::MD5.hexdigest(storage.read("info/rake"))

        assert_equal info_md5, record[2],
          "/versions checksum must equal the checksum of the served /info file"
      end

      test "yanked versions are excluded from /info but shown with '-' in /versions" do
        rake = rubygems(:rake)
        rake.versions.create!(number: "13.2.2", platform: "ruby",
          full_name: "rake-13.2.2", indexed: true, yanked_at: Time.current)
        storage = Storage.new("v1")

        info = V1.keyed_body_for(:info, "rake")
        refute_includes info, "13.2.2", "/info must not list a yanked version"

        record = V1.versions_record(rake, storage)
        assert_includes record[1], "-13.2.2", "/versions must mark the yank with '-'"
        assert_includes record[1], "13.2.1", "/versions must still list the live version"
      end

      test "non-ruby platform versions get a -platform suffix in labels" do
        rake = rubygems(:rake)
        rake.versions.create!(number: "13.2.1", platform: "java",
          full_name: "rake-13.2.1-java", indexed: true)
        storage = Storage.new("v1")

        record = V1.versions_record(rake, storage)
        assert_includes record[1], "13.2.1-java"
      end

      test "rubygem_for_change resolves all three record types" do
        rake = rubygems(:rake)
        version = versions(:rake_13_2_1)

        assert_equal rake, V1.rubygem_for_change(record_type: "Rubygem", record_id: rake.id)
        assert_equal rake, V1.rubygem_for_change(record_type: "Version", record_id: version.id)
      end
    end
  end
end
