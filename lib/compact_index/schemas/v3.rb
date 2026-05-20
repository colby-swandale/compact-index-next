module CompactIndex
  module Schemas
    # V3 — V2 plus a new ContentAddressed resource for pre-compiled
    # native gem manifests.
    #
    # This is the "thin spike" that proves the engine's resource-type
    # taxonomy admits structurally new kinds of resources without forcing
    # changes to v1/v2 schemas. The CAS resource publishes manifest
    # pointers (platform, ruby_abi, source_url) — not the binaries
    # themselves, which would live in object storage keyed by the same
    # sha256.
    class V3 < V2
      schema_id "v3"

      resource :cas, type: Resources::ContentAddressed

      # ---------- ContentAddressed: /cas/<sha256> ----------

      def self.content_addressed_dirty_for(_name, change)
        type = change[:record_type] || change["record_type"]
        id   = change[:record_id]   || change["record_id"]

        case type
        when "BuildArtifact"
          BuildArtifact.where(id: id).pluck(:sha256)
        when "Version"
          BuildArtifact.where(version_id: id).pluck(:sha256)
        else
          []
        end
      end

      def self.content_addressed_all_for(_name)
        BuildArtifact.pluck(:sha256)
      end

      def self.content_addressed_body_for(_name, sha)
        artifact = BuildArtifact.find_by(sha256: sha)
        return nil unless artifact

        version = artifact.version
        gem = version.rubygem

        JSON.pretty_generate(
          sha256: artifact.sha256,
          gem: gem.name,
          version: version.number,
          platform: artifact.platform,
          ruby_abi: artifact.ruby_abi,
          size: artifact.size,
          source_url: artifact.source_url,
          built_at: artifact.created_at.utc.iso8601
        )
      end
    end
  end
end
