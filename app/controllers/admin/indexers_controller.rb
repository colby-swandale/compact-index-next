module Admin
  # Per-version observability surface. Exposes cursor position, lag, and
  # paused state for each schema as JSON. The lag metric is the headline
  # operational signal — "is v2 falling behind?" becomes a quantifiable
  # number rather than an inference.
  class IndexersController < ActionController::Base
    def index
      max_canonical_at = [
        Version.maximum(:updated_at),
        Rubygem.maximum(:updated_at),
        BuildArtifact.maximum(:updated_at)
      ].compact.max

      rows = CompactIndex.schema_names.map do |schema_name|
        cursor = IndexCursor.for(schema_name)
        {
          schema: schema_name,
          paused: cursor.paused,
          last_processed_at: cursor.last_processed_at&.utc&.iso8601,
          lag_seconds: cursor.lag_seconds,
          resources: CompactIndex.schema(schema_name).resources.keys
        }
      end

      render json: {
        max_canonical_updated_at: max_canonical_at&.utc&.iso8601,
        indexers: rows
      }
    end
  end
end
