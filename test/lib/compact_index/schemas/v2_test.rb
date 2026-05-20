require "test_helper"

module CompactIndex
  module Schemas
    class V2Test < ActiveSupport::TestCase
      test "adds created_at to /info records but keeps everything else identical" do
        rake = rubygems(:rake)
        rake.versions.update_all(sha256: "deadbeef" * 8, required_ruby_version: ">= 3.0.0")

        v1_body = V1.keyed_body_for(:info, "rake")
        v2_body = V2.keyed_body_for(:info, "rake")

        refute_includes v1_body, "created_at:"
        assert_includes v2_body, "created_at:"
        # v2 should be v1 with a created_at appended to each record line
        assert_equal v1_body.lines.length, v2_body.lines.length
      end

      test "inherits resources from v1" do
        resources = V2.resources.keys
        assert_includes resources, "versions"
        assert_includes resources, "names"
        assert_includes resources, "info"
      end

      test "/names body identical to v1" do
        assert_equal V1.single_file_body_for(:names),
                     V2.single_file_body_for(:names)
      end
    end
  end
end
