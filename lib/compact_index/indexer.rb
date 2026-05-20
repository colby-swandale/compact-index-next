module CompactIndex
  # Generic per-version indexer. Constructed with a Schema class; advances
  # all of that schema's resources in response to a change in the canonical
  # DB. Each schema has its own Indexer instance; siblings are independent.
  class Indexer
    attr_reader :schema, :storage, :cursor

    def initialize(schema)
      @schema = schema
      @storage = Storage.new(schema.schema_id)
      @cursor = IndexCursor.for(schema.schema_id)
    end

    # Apply one change (a single record-touched event) across every resource
    # this schema produces. Resources decide which records are relevant to
    # them; the indexer just fans the change out.
    def advance(change)
      return if @cursor.paused

      @schema.resources.each_key do |resource_name|
        resource = @schema.resource_for(resource_name)
        resource.materialize(@storage, change)
      end

      @cursor.update!(last_processed_at: Time.current)
    end

    # Full rebuild from the canonical DB. Wipes per-schema storage and
    # re-projects every resource from scratch. The same code path used for
    # disaster recovery and for bootstrapping a brand-new schema.
    def rebuild!
      @storage.clear!

      @schema.resources.each_key do |resource_name|
        resource = @schema.resource_for(resource_name)
        resource.rebuild(@storage)
      end

      @cursor.update!(last_processed_at: Time.current)
    end
  end
end
