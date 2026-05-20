module CompactIndex
  module Resources
    # Keyed — the /info/<gem>-style resource.
    #
    # One file per key. When a key's records change the whole file for that
    # key is rewritten (per-version info files are small; this is what
    # rubygems.org does today). The content checksum is what gets propagated
    # into the AppendOnlyLog /versions record for that gem; the engine
    # exposes content_checksum_for to make that linkage explicit.
    class Keyed < Base
      def materialize(storage, change)
        keys = @schema.keyed_dirty_keys_for(@name, change)
        keys.each { |key| rewrite_key(storage, key) }
      end

      def rebuild(storage)
        @schema.keyed_all_keys_for(@name).each do |key|
          rewrite_key(storage, key)
        end
      end

      def serve(storage, params)
        key = params.fetch(:key)
        body = storage.read(path_for(key)) || @schema.keyed_body_for(@name, key)
        return nil if body.nil?

        {
          body: body,
          content_type: "text/plain; charset=utf-8",
          last_modified: storage.mtime(path_for(key)) || Time.at(0),
          etag: Digest::MD5.hexdigest(body)
        }
      end

      # Content-checksum of a key's file. The AppendOnlyLog /versions
      # resource uses this to stamp each line.
      def content_checksum_for(storage, key)
        body = storage.read(path_for(key))
        body ||= @schema.keyed_body_for(@name, key)
        return nil if body.nil?

        Digest::MD5.hexdigest(body)
      end

      def path_for(key)
        "#{@name}/#{key}"
      end

      private

      def rewrite_key(storage, key)
        body = @schema.keyed_body_for(@name, key)
        if body
          storage.write(path_for(key), body)
        end
      end
    end
  end
end
