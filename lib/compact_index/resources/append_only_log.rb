module CompactIndex
  module Resources
    # AppendOnlyLog — the /versions-style resource.
    #
    # Records are appended in order, never rewritten in place. Each record
    # corresponds to one gem at a given snapshot ("gem foo now has these
    # versions, with this checksum on its /info file"). Range requests rely
    # on the never-rewrite invariant for the existing prefix.
    #
    # Appends are idempotent against job retries: if the candidate line is
    # byte-identical to the most recent line already recorded for that gem,
    # it is skipped. (Full multi-source ordered idempotency would require a
    # durable change-sequence — an events/outbox table — which is out of
    # scope for this prototype; see SRE review notes in the design doc.)
    class AppendOnlyLog < Base
      def header
        @schema.append_only_log_header_for(@name)
      end

      def materialize(storage, change)
        records = @schema.append_only_log_records_for(@name, change, storage)
        return if records.empty?

        ensure_header(storage)
        existing = storage.read(path).to_s
        records.each do |record|
          line = Engine.encode_log_line(record)
          next if last_line_for_key(existing, record.first) == line

          storage.append(path, line)
          existing = existing + line
        end
      end

      def rebuild(storage)
        storage.write(path, header.to_s)
        ordered_records = @schema.append_only_log_full_history(@name, storage)
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

      # Most recent appended line for a given gem key, or nil.
      def last_line_for_key(content, key)
        prefix = "#{key} "
        content.each_line.select { |line| line.start_with?(prefix) }.last
      end
    end
  end
end
