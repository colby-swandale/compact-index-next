# Mixin that surfaces canonical-DB writes to the compact-index indexers.
#
# The write path itself (a gem push, a yank, a build artifact registration)
# is unchanged. This concern just enqueues one AdvanceIndexerJob per active
# schema after the writing transaction commits. The job is the unit that
# advances a single (schema, record) projection; siblings move independently.
module EmitsIndexChange
  extend ActiveSupport::Concern

  included do
    after_commit :emit_compact_index_change, on: [ :create, :update ]
  end

  private

  def emit_compact_index_change
    CompactIndex.schema_names.each do |schema_name|
      CompactIndex::AdvanceIndexerJob.perform_later(
        schema_name: schema_name,
        record_type: self.class.name,
        record_id: id
      )
    end
  end
end
