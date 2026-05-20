module CompactIndex
  # Idempotent full rebuild of one schema's artifacts from the canonical
  # DB. Wipes per-schema storage, re-projects every resource. Used for
  # disaster recovery and for bootstrapping a newly-added schema.
  class BackfillJob < ApplicationJob
    queue_as :default

    def perform(schema_name:)
      schema = CompactIndex.schema(schema_name)
      Indexer.new(schema).rebuild!
    end
  end
end
