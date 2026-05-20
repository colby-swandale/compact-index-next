module CompactIndex
  module Resources
    # ContentAddressed — the /cas/<sha256>-style resource (v3+).
    #
    # Each artifact is addressed by its content hash. Manifests are
    # immutable once written; deduplication across versions falls out of
    # the addressing. This prototype publishes manifest pointers (platform,
    # ABI, source URL) — the binaries themselves live in object storage
    # keyed by the same sha256 and are a separate concern.
    class ContentAddressed < Base
      def materialize(storage, change)
        hashes = @schema.content_addressed_dirty_for(@name, change)
        hashes.each { |sha| write_manifest(storage, sha) }
      end

      def rebuild(storage)
        @schema.content_addressed_all_for(@name).each do |sha|
          write_manifest(storage, sha)
        end
      end

      def serve(storage, params)
        sha = params.fetch(:key)
        body = storage.read(path_for(sha)) || @schema.content_addressed_body_for(@name, sha)
        return nil if body.nil?

        {
          body: body,
          content_type: "application/json",
          last_modified: storage.mtime(path_for(sha)) || Time.at(0),
          etag: sha
        }
      end

      def path_for(sha)
        "#{@name}/#{sha}"
      end

      private

      def write_manifest(storage, sha)
        body = @schema.content_addressed_body_for(@name, sha)
        return unless body

        return if storage.exist?(path_for(sha))

        storage.write(path_for(sha), body)
      end
    end
  end
end
