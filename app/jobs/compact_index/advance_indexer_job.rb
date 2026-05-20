module CompactIndex
  # Enqueued by EmitsIndexChange after_commit callbacks. Advances one
  # schema's indexer in response to one canonical-DB record change.
  #
  # One job per (schema, record) pair keeps siblings independent: a slow
  # or failing v3 indexer cannot affect v1 or v2.
  class AdvanceIndexerJob < ApplicationJob
    queue_as :default

    def perform(schema_name:, record_type:, record_id:)
      schema = CompactIndex.schema(schema_name)
      Indexer.new(schema).advance(record_type: record_type, record_id: record_id)
    end
  end
end
