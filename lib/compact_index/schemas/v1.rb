module CompactIndex
  module Schemas
    # V1 — the current rubygems.org compact-index format.
    #
    # Acts as the compatibility anchor: proves the engine can reproduce
    # today's wire format from the canonical DB byte-for-byte against
    # seeded data.
    #
    # Three resource instances:
    #   versions  - AppendOnlyLog : /v1/versions
    #   names     - SingleFile    : /v1/names
    #   info      - Keyed         : /v1/info/<gem>
    class V1 < Schema
      name "v1"

      resource :versions, type: Resources::AppendOnlyLog
      resource :names,    type: Resources::SingleFile
      resource :info,     type: Resources::Keyed

      # ---------- shared helpers ----------

      def self.indexed_gems
        Rubygem.where(indexed: true).order(:name)
      end

      def self.indexed_versions_for(rubygem)
        rubygem.versions.where(indexed: true).order(:created_at, :id)
      end

      # ---------- AppendOnlyLog: /versions ----------

      def self.append_only_log_header_for(_name)
        "created_at: #{Time.current.utc.iso8601}\n---\n"
      end

      def self.append_only_log_records_for(_name, change)
        rubygem = rubygem_for_change(change)
        return [] unless rubygem
        return [] unless rubygem.indexed?

        [ versions_record(rubygem) ].compact
      end

      def self.append_only_log_full_history(_name)
        indexed_gems.flat_map do |gem|
          rec = versions_record(gem)
          rec ? [ rec ] : []
        end
      end

      def self.versions_record(rubygem)
        versions = indexed_versions_for(rubygem)
        return nil if versions.empty?

        version_list = versions.map { |v| version_label(v) }.join(",")
        info_md5 = info_checksum(rubygem)
        [ rubygem.name, version_list, info_md5 ]
      end

      def self.version_label(v)
        v.platform == "ruby" ? v.number : "#{v.number}-#{v.platform}"
      end

      def self.info_checksum(rubygem)
        Digest::MD5.hexdigest(info_body(rubygem))
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
        reqs[:ruby] = version.required_ruby_version if version.required_ruby_version.present?
        reqs[:rubygems] = version.required_rubygems_version if version.required_rubygems_version.present?
        reqs
      end

      def self.dep_pairs(version)
        version.dependencies
          .where(scope: "runtime")
          .order(:unresolved_name)
          .map { |d| [ d.unresolved_name, d.requirements ] }
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
