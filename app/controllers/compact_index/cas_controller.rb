module CompactIndex
  class CasController < BaseController
    def show
      render_resource(:cas, key: params[:sha256])
    end
  end
end
