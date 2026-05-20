module CompactIndex
  # Thin base controller: looks up a schema + resource, asks the engine
  # for the serve payload, and writes it to the response. Per-resource
  # controllers below are one or two lines each.
  #
  # Inherits ActionController::Base directly rather than ApplicationController
  # because compact-index clients (Bundler, RubyGems CLI) are not browsers;
  # the modern-browser gate in ApplicationController doesn't apply.
  class BaseController < ActionController::Base
    private

    def schema
      @schema ||= ::CompactIndex.schema(params[:version])
    rescue ArgumentError
      head :not_found
      nil
    end

    def render_resource(resource_name, key: nil)
      return unless schema

      resource = schema.resource_for(resource_name)
      if resource.nil?
        head :not_found
        return
      end

      payload = resource.serve(::CompactIndex::Storage.new(schema.schema_id), key: key)
      if payload.nil?
        head :not_found
        return
      end

      serve_payload(payload)
    end

    # Conditional GET + Range. The compact-index format is built around
    # clients fetching only the appended suffix of /versions via Range, and
    # re-validating cached files via ETag/If-Modified-Since — so both are
    # first-class here, not afterthoughts.
    def serve_payload(payload)
      body = payload[:body]
      content_type = payload[:content_type]

      response.headers["Accept-Ranges"] = "bytes"
      # Repr-Digest carries the SHA256 of the FULL representation (RFC 9530),
      # so a client assembling a file from Range responses can verify the
      # result. Computed on the full body even for 206/304 responses.
      response.headers["Repr-Digest"] = "sha-256=:#{Base64.strict_encode64(Digest::SHA256.digest(body))}:"
      expires_in 60.seconds, public: true

      # 304 short-circuit. stale? returns false (and sets a 304 response)
      # when the client's cached copy is still fresh.
      return unless stale?(etag: payload[:etag], last_modified: payload[:last_modified])

      range = request.headers["Range"]
      ranges = Rack::Utils.get_byte_ranges(range, body.bytesize) if range.present?

      if ranges && ranges.empty?
        response.headers["Content-Range"] = "bytes */#{body.bytesize}"
        head :range_not_satisfiable
      elsif ranges && ranges.size == 1
        slice = ranges.first
        response.status = :partial_content
        response.headers["Content-Range"] = "bytes #{slice.begin}-#{slice.end}/#{body.bytesize}"
        send_data body.byteslice(slice), type: content_type, disposition: "inline"
      else
        # No range, or multi-range (unsupported) -> serve full body.
        send_data body, type: content_type, disposition: "inline"
      end
    end
  end
end
