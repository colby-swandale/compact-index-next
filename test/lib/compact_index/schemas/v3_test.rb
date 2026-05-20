require "test_helper"

module CompactIndex
  module Schemas
    class V3Test < ActiveSupport::TestCase
      test "declares a CAS resource on top of v2's three resources" do
        assert_equal %w[versions names info cas], V3.resources.keys
      end

      test "content_addressed_all_for returns every artifact sha" do
        shas = V3.content_addressed_all_for(:cas)
        assert_includes shas, build_artifacts(:rake_linux_ruby33).sha256
        assert_includes shas, build_artifacts(:rake_darwin_ruby33).sha256
      end

      test "content_addressed_body_for returns a JSON manifest for a known sha" do
        artifact = build_artifacts(:rake_linux_ruby33)
        body = V3.content_addressed_body_for(:cas, artifact.sha256)
        manifest = JSON.parse(body)

        assert_equal artifact.sha256, manifest["sha256"]
        assert_equal "rake", manifest["gem"]
        assert_equal "13.2.1", manifest["version"]
        assert_equal "x86_64-linux-gnu", manifest["platform"]
        assert_equal "ruby33", manifest["ruby_abi"]
      end

      test "v3 keyed_body_for(:info) still includes created_at (inherits v2)" do
        body = V3.keyed_body_for(:info, "rake")
        assert_includes body, "created_at:"
      end
    end
  end
end
