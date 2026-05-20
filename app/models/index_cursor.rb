class IndexCursor < ApplicationRecord
  validates :schema_name, presence: true, uniqueness: true

  scope :active, -> { where(paused: false) }

  def self.for(schema_name)
    find_or_create_by!(schema_name: schema_name.to_s)
  end

  def lag_seconds
    return nil unless last_processed_at

    max_changed_at = [
      Version.maximum(:updated_at),
      Rubygem.maximum(:updated_at),
      (BuildArtifact.maximum(:updated_at) if defined?(BuildArtifact))
    ].compact.max

    return 0 unless max_changed_at

    (max_changed_at - last_processed_at).clamp(0, Float::INFINITY).to_i
  end
end
