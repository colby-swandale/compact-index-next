module CompactIndex
  class InfoController < BaseController
    def show
      render_resource(:info, key: params[:gem])
    end
  end
end
