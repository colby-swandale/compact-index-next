# CompactIndex is the engine + schema registry for serving multiple
# versions of the rubygems.org compact index from the same canonical DB.
#
# Pattern: CQRS read-model materialization (no event sourcing).
#   - Canonical DB (Rubygem / Version / Dependency / BuildArtifact) is the
#     source of truth. Write path stays Rails-conventional.
#   - For each compact-index version (v1, v2, v3, ...) a Schema declares
#     which engine-level resources it produces and what records they hold.
#   - A generic Indexer, parameterised by a Schema, materialises that
#     version's artifacts on disk. Sibling versions are isolated.
#
# Adding a new compact-index version = add a file under lib/compact_index/schemas/
# and a line in CompactIndex.schemas. The engine itself does not change for
# additive-field versions; only for new *resource types* (e.g. v3's CAS).
module CompactIndex
  def self.schemas
    @schemas ||= {
      "v1" => CompactIndex::Schemas::V1,
      "v2" => CompactIndex::Schemas::V2,
      "v3" => CompactIndex::Schemas::V3
    }
  end

  def self.schema_names
    schemas.keys
  end

  def self.schema(name)
    schemas.fetch(name.to_s) do
      raise ArgumentError, "Unknown compact index schema: #{name.inspect}. Known: #{schema_names.inspect}"
    end
  end

  def self.storage_root
    @storage_root ||= Rails.root.join("storage", "index")
  end

  def self.storage_root=(path)
    @storage_root = path && Pathname.new(path)
  end
end
