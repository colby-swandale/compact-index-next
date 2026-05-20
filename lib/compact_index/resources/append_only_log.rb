module CompactIndex
  module Resources
    # AppendOnlyLog — the /versions-style resource.
    #
    # Records are appended in order, never rewritten in place. Each record
    # corresponds to one gem at a given snapshot ("gem foo now has these
    # versions, with this checksum on its /info file"). Range requests rely
    # on the never-rewrite invariant for the existing prefix.
    #
    # The header is written once at file creation; the materialiser is
    # responsible for ensuring it exists before appending records.
    class AppendOnlyLog < Base
      def header
        @schema.append_only_log_header_for(@name)
      end

      def materialize(storage, change)
        records = @schema.append_only_log_records_for(@name, change)
        return if records.empty?

        ensure_header(storage)
        body = records.map { |r| Engine.encode_log_line(r) }.join
        storage.append(path, body)
      end

      def rebuild(storage)
        storage.write(path, header.to_s)
        ordered_records = @schema.append_only_log_full_history(@name)
        ordered_records.each_slice(500) do |chunk|
          body = chunk.map { |r| Engine.encode_log_line(r) }.join
          storage.append(path, body)
        end
      end

      def serve(storage, _params)
        body = storage.read(path) || header.to_s
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

      private

      def ensure_header(storage)
        return if storage.exist?(path)

        storage.write(path, header.to_s)
      end
    end
  end
end
