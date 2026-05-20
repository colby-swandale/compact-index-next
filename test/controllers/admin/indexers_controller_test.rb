require "test_helper"

module Admin
  class IndexersControllerTest < ActionDispatch::IntegrationTest
    test "lists every schema's cursor + lag" do
      get "/admin/indexers"
      assert_response :success

      json = JSON.parse(response.body)
      schemas = json["indexers"].map { |row| row["schema"] }
      assert_equal %w[v1 v2 v3], schemas

      v1 = json["indexers"].find { |row| row["schema"] == "v1" }
      assert_equal false, v1["paused"]
      assert_equal %w[info names versions].sort, v1["resources"].sort

      v3 = json["indexers"].find { |row| row["schema"] == "v3" }
      assert_includes v3["resources"], "cas"
    end
  end
end
