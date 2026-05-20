module CompactIndex
  class NamesController < BaseController
    def show
      render_resource(:names)
    end
  end
end
