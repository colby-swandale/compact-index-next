module CompactIndex
  # Base class for a compact-index schema (one per wire-format version).
  #
  # A schema:
  #   1. Picks resource instances from the engine's taxonomy.
  #   2. Declares which records each resource contains and the source
  #      projection (canonical-DB query) used to build them.
  #
  # A schema does NOT implement materialisation or serving — that lives in
  # the engine. The methods below are the surface the resource types call
  # into; concrete subclasses override the ones that are relevant for the
  # resource types they include.
  class Schema
    class << self
      # Copy the parent class's declared resources so subclasses inherit them.
      # V2 < V1 adds zero resources of its own but should still produce the
      # versions/names/info resources V1 declared.
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@resources, resources.dup)
      end

      def name(value = nil)
        if value
          @name = value
        else
          @name
        end
      end

      def resource(name, type:)
        @resources ||= {}
        @resources[name.to_s] = type
        @resource_instances = nil
      end

      def resources
        @resources ||= {}
      end

      def build_resources
        resources.map { |res_name, type|
          [ res_name, type.new(schema: self, name: res_name) ]
        }.to_h
      end
    end

    # Resources lookup — used by the indexer and controllers.
    def self.resource_for(name)
      @resource_instances ||= build_resources
      @resource_instances[name.to_s]
    end

    # ----- AppendOnlyLog hooks -----

    # Header written once at the top of an append-only log file.
    def self.append_only_log_header_for(_resource_name)
      ""
    end

    # Records to append for an incremental change. `change` is a hash like
    # { record_type: "Version", record_id: 123 }.
    def self.append_only_log_records_for(_resource_name, _change)
      []
    end

    # Full ordered history of records — used during rebuild.
    def self.append_only_log_full_history(_resource_name)
      []
    end

    # ----- SingleFile hooks -----

    def self.single_file_body_for(_resource_name)
      ""
    end

    # ----- Keyed hooks -----

    def self.keyed_dirty_keys_for(_resource_name, _change)
      []
    end

    def self.keyed_all_keys_for(_resource_name)
      []
    end

    def self.keyed_body_for(_resource_name, _key)
      nil
    end

    # ----- ContentAddressed hooks -----

    def self.content_addressed_dirty_for(_resource_name, _change)
      []
    end

    def self.content_addressed_all_for(_resource_name)
      []
    end

    def self.content_addressed_body_for(_resource_name, _sha)
      nil
    end
  end
end
