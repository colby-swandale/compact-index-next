module CompactIndex
  module Schemas
    # V2 — V1 plus a `created_at` requirement field on /info records.
    #
    # The whole delta is one method override: info_requirements adds the
    # created_at field. /versions and /names are identical to v1.
    # This is the additive-field path the architecture is designed to make
    # cheap: schema delta only, engine untouched.
    class V2 < V1
      schema_id "v2"

      def self.info_requirements(version)
        reqs = super
        reqs[:created_at] = version.created_at.utc.iso8601 if version.created_at
        reqs
      end
    end
  end
end
