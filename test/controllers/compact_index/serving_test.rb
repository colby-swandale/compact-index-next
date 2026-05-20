require "test_helper"

module CompactIndex
  class ServingTest < ActionDispatch::IntegrationTest
    setup do
      # Build artifacts so all three schemas have something to serve
      Indexer.new(Schemas::V1).rebuild!
      Indexer.new(Schemas::V2).rebuild!
      Indexer.new(Schemas::V3).rebuild!
    end

    test "GET /v1/versions serves the append-only log" do
      get "/v1/versions"
      assert_response :success
      assert_match(/^---$/, response.body)
      assert_match(/^rake 13\.2\.1 [0-9a-f]{32}$/, response.body)
    end

    test "GET /v2/versions is structurally the same as v1" do
      get "/v2/versions"
      assert_response :success
      assert_match(/^rake 13\.2\.1 [0-9a-f]{32}$/, response.body)
    end

    test "GET /v1/info/rake does NOT include created_at" do
      get "/v1/info/rake"
      assert_response :success
      refute_includes response.body, "created_at:"
    end

    test "GET /v2/info/rake DOES include created_at" do
      get "/v2/info/rake"
      assert_response :success
      assert_includes response.body, "created_at:"
    end

    test "GET /v1/names lists all indexed gems" do
      get "/v1/names"
      assert_response :success
      assert_includes response.body, "rake"
      assert_includes response.body, "bundler"
    end

    test "GET /v3/cas/<sha> returns JSON manifest" do
      sha = build_artifacts(:rake_linux_ruby33).sha256
      get "/v3/cas/#{sha}"
      assert_response :success
      manifest = JSON.parse(response.body)
      assert_equal sha, manifest["sha256"]
      assert_equal "rake", manifest["gem"]
    end

    test "GET /v1/cas/<sha> 404s (v1 has no CAS resource)" do
      sha = build_artifacts(:rake_linux_ruby33).sha256
      get "/v1/cas/#{sha}"
      assert_response :not_found
    end

    test "GET /v9/versions 404s (unknown schema)" do
      get "/v9/versions"
      assert_response :not_found
    end

    test "responses carry ETag and Last-Modified headers" do
      get "/v2/info/rake"
      assert_response :success
      assert_match(/\A".+"\z/, response.headers["ETag"])
      assert response.headers["Last-Modified"].present?
    end
  end
end
