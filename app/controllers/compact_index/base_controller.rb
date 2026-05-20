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

      payload = resource.serve(::CompactIndex::Storage.new(schema.name), key: key)
      if payload.nil?
        head :not_found
        return
      end

      response.set_header("ETag", %Q("#{payload[:etag]}"))
      response.set_header("Last-Modified", payload[:last_modified].httpdate)
      send_data payload[:body], type: payload[:content_type], disposition: "inline"
    end
  end
end
