module CompactIndex
  class VersionsController < BaseController
    def show
      render_resource(:versions)
    end
  end
end
