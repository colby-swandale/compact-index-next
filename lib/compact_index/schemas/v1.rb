module CompactIndex
  module Schemas
    # V1 — the current rubygems.org compact-index format.
    #
    # Acts as the compatibility anchor: proves the engine can reproduce
    # today's wire format from the canonical DB byte-for-byte against
    # seeded data.
    #
    # Three resource instances. Declaration order matters: `info` is
    # declared before `versions` so the indexer materializes each gem's
    # /info file *before* the /versions line that stamps that file's
    # checksum (see versions_record).
    #   info      - Keyed         : /v1/info/<gem>
    #   names     - SingleFile    : /v1/names
    #   versions  - AppendOnlyLog : /v1/versions
    class V1 < Schema
      schema_id "v1"

      resource :info,     type: Resources::Keyed
      resource :names,    type: Resources::SingleFile
      resource :versions, type: Resources::AppendOnlyLog

      # ---------- shared helpers ----------

      def self.indexed_gems
        Rubygem.where(indexed: true).order(:name)
      end

      # Versions that are installable: indexed and not yanked. This is what
      # /info lists and what the un-prefixed entries in /versions reflect.
      def self.indexed_versions_for(rubygem)
        rubygem.versions.where(indexed: true, yanked_at: nil).order(:created_at, :id)
      end

      # ---------- AppendOnlyLog: /versions ----------

      def self.append_only_log_header_for(_name)
        "created_at: #{Time.current.utc.iso8601}\n---\n"
      end

      def self.append_only_log_records_for(_name, change, storage)
        rubygem = rubygem_for_change(change)
        return [] unless rubygem
        return [] unless rubygem.indexed?

        [ versions_record(rubygem, storage) ].compact
      end

      def self.append_only_log_full_history(_name, storage)
        indexed_gems.filter_map { |gem| versions_record(gem, storage) }
      end

      # [gem_name, "v1,v2,-yanked", info_checksum]. The checksum is read from
      # the materialized /info file (not recomputed from the DB) so a
      # /versions line always points at the bytes actually being served.
      def self.versions_record(rubygem, storage)
        labels = listed_version_labels(rubygem)
        return nil if labels.empty?

        info_md5 = resource_for(:info).content_checksum_for(storage, rubygem.name)
        [ rubygem.name, labels.join(","), info_md5 ]
      end

      # All listed versions in natural (creation) order, each prefixed with
      # "-" if yanked (the compact-index removal marker). Matches the spec's
      # `RUBYGEM [-]VERSION[,VERSION,...]` layout where yanks appear in place.
      def self.listed_version_labels(rubygem)
        rubygem.versions
          .where("indexed = ? OR yanked_at IS NOT NULL", true)
          .order(:created_at, :id)
          .map { |v| v.yanked_at ? "-#{version_label(v)}" : version_label(v) }
      end

      def self.version_label(v)
        v.platform == "ruby" ? v.number : "#{v.number}-#{v.platform}"
      end

      # ---------- SingleFile: /names ----------

      def self.single_file_body_for(_name)
        Engine.names_header + indexed_gems.pluck(:name).join("\n") + "\n"
      end

      # ---------- Keyed: /info/<gem> ----------

      def self.keyed_dirty_keys_for(_name, change)
        rubygem = rubygem_for_change(change)
        rubygem ? [ rubygem.name ] : []
      end

      def self.keyed_all_keys_for(_name)
        indexed_gems.pluck(:name)
      end

      def self.keyed_body_for(_name, key)
        rubygem = Rubygem.find_by(name: key, indexed: true)
        return nil unless rubygem

        info_body(rubygem)
      end

      def self.info_body(rubygem)
        body = Engine.info_header.dup
        indexed_versions_for(rubygem).each do |version|
          body << Engine.encode_info_line(
            version_string: version_label(version),
            deps: dep_pairs(version),
            requirements: info_requirements(version)
          )
        end
        body
      end

      def self.info_requirements(version)
        reqs = {}
        reqs[:checksum] = version.sha256 if version.sha256.present?
        reqs[:ruby] = format_constraints(version.required_ruby_version) if version.required_ruby_version.present?
        reqs[:rubygems] = format_constraints(version.required_rubygems_version) if version.required_rubygems_version.present?
        reqs
      end

      def self.dep_pairs(version)
        version.dependencies
          .where(scope: "runtime")
          .order(:unresolved_name)
          .map { |d| [ d.unresolved_name, format_constraints(d.requirements) ] }
      end

      # Multiple version constraints within a single requirement are joined
      # with "&" per the spec, because "," is reserved as the delimiter
      # between dependencies. Gem::Requirement#to_s renders them with ", ",
      # which would corrupt the line if passed through.
      def self.format_constraints(requirement_string)
        requirement_string.to_s.split(", ").join("&")
      end

      # ---------- change routing ----------

      def self.rubygem_for_change(change)
        type = change[:record_type] || change["record_type"]
        id   = change[:record_id]   || change["record_id"]

        case type
        when "Rubygem"
          Rubygem.find_by(id: id)
        when "Version"
          Version.find_by(id: id)&.rubygem
        when "BuildArtifact"
          BuildArtifact.find_by(id: id)&.version&.rubygem
        end
      end
    end
  end
end
