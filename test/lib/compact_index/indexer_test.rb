require "test_helper"

module CompactIndex
  class IndexerTest < ActiveSupport::TestCase
    test "rebuild! writes all resources for the schema" do
      Indexer.new(Schemas::V1).rebuild!
      storage = Storage.new("v1")

      assert storage.exist?("versions"), "/versions file should be written"
      assert storage.exist?("names"),    "/names file should be written"
      assert storage.exist?("info/rake"), "/info/rake should be written"
    end

    test "rebuild! is isolated to the schema's namespace" do
      Indexer.new(Schemas::V1).rebuild!
      v1_versions = Storage.new("v1").read("versions")
      refute_nil v1_versions

      # v2 storage should be untouched
      assert_nil Storage.new("v2").read("versions")
    end

    test "rebuild! advances cursor's last_processed_at" do
      cursor = IndexCursor.for("v1")
      cursor.update!(last_processed_at: nil)

      Indexer.new(Schemas::V1).rebuild!

      assert_not_nil cursor.reload.last_processed_at
    end

    test "advance is a no-op when cursor is paused" do
      cursor = IndexCursor.for("v1")
      Indexer.new(Schemas::V1).rebuild!
      pre_processed_at = cursor.reload.last_processed_at

      cursor.update!(paused: true)
      sleep 0.01
      Indexer.new(Schemas::V1).advance(
        record_type: "Version", record_id: versions(:rake_13_2_1).id
      )

      assert_equal pre_processed_at, cursor.reload.last_processed_at
    end

    test "advance appends to /versions without rewriting earlier lines" do
      Indexer.new(Schemas::V1).rebuild!
      storage = Storage.new("v1")
      original = storage.read("versions")

      # Touch a gem to trigger a new append
      rake = rubygems(:rake)
      Indexer.new(Schemas::V1).advance(record_type: "Rubygem", record_id: rake.id)

      after = storage.read("versions")
      assert after.start_with?(original), "earlier content must be preserved (append-only invariant)"
      assert_operator after.length, :>=, original.length
    end
  end
end
