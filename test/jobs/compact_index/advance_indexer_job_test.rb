require "test_helper"

module CompactIndex
  class AdvanceIndexerJobTest < ActiveJob::TestCase
    test "creating a Version enqueues one AdvanceIndexerJob per schema" do
      rake = rubygems(:rake)

      assert_enqueued_jobs CompactIndex.schema_names.size, only: AdvanceIndexerJob do
        rake.versions.create!(number: "13.4.0", platform: "ruby", full_name: "rake-13.4.0", indexed: true)
      end
    end

    test "the real after_commit -> job -> advance path materializes the new version" do
      # Seed baseline state for v1 so /versions and /info exist.
      Indexer.new(Schemas::V1).rebuild!
      storage = Storage.new("v1")
      before = storage.read("info/rake")
      refute_includes before.to_s, "13.5.0"

      perform_enqueued_jobs do
        rubygems(:rake).versions.create!(
          number: "13.5.0", platform: "ruby", full_name: "rake-13.5.0",
          indexed: true, sha256: "c" * 64
        )
      end

      after_info = storage.read("info/rake")
      assert_includes after_info, "13.5.0", "/info should reflect the new version via the job path"

      versions = storage.read("versions")
      rake_lines = versions.each_line.select { |l| l.start_with?("rake ") }
      assert_includes rake_lines.last, "13.5.0", "newest /versions line for rake should include the new version"
    end

    test "re-running an identical advance does not double-append to /versions" do
      Indexer.new(Schemas::V1).rebuild!
      storage = Storage.new("v1")
      rake = rubygems(:rake)

      change = { record_type: "Rubygem", record_id: rake.id }
      Indexer.new(Schemas::V1).advance(change)
      after_first = storage.read("versions").each_line.count { |l| l.start_with?("rake ") }

      # Identical retry (same DB state) must be a no-op append.
      Indexer.new(Schemas::V1).advance(change)
      after_retry = storage.read("versions").each_line.count { |l| l.start_with?("rake ") }

      assert_equal after_first, after_retry, "identical retry must not double-append"
    end
  end
end
