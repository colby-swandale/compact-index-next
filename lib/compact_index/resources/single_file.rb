module CompactIndex
  module Resources
    # SingleFile — the /names-style resource.
    #
    # A small file fully regenerated whenever the underlying keyset changes.
    # Cheap to rebuild; no per-change delta needed.
    class SingleFile < Base
      def materialize(storage, _change)
        rebuild(storage)
      end

      def rebuild(storage)
        body = @schema.single_file_body_for(@name)
        storage.write(path, body)
      end

      def serve(storage, _params)
        body = storage.read(path) || @schema.single_file_body_for(@name)
        {
          body: body,
          content_type: "text/plain; charset=utf-8",
          last_modified: storage.mtime(path) || Time.at(0),
          etag: Digest::MD5.hexdigest(body)
        }
      end

      def path
        @name
      end
    end
  end
end
