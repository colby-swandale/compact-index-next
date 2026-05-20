module CompactIndex
  module Resources
    # Base class for the four engine-level resource types.
    #
    # A resource is the unit the engine knows how to materialise and serve.
    # Schemas pick from the taxonomy below and bind records to them; they
    # do not implement their own materialisation logic.
    #
    # Subclasses must implement:
    #   #materialize(storage, change) -> writes/refreshes artifacts in storage
    #   #serve(storage, params)       -> returns { body:, content_type:, etag:, last_modified: }
    class Base
      attr_reader :name, :schema

      def initialize(schema:, name:)
        @schema = schema
        @name = name.to_s
      end

      def materialize(_storage, _change)
        raise NotImplementedError
      end

      def serve(_storage, _params)
        raise NotImplementedError
      end

      def rebuild(_storage)
        raise NotImplementedError
      end
    end
  end
end
