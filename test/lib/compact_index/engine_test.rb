require "test_helper"

module CompactIndex
  class EngineTest < ActiveSupport::TestCase
    test "encode_log_line joins fields with spaces and terminates with newline" do
      line = Engine.encode_log_line([ "rake", "13.2.1", "abc123" ])
      assert_equal "rake 13.2.1 abc123\n", line
    end

    test "encode_info_line joins deps and requirements as expected" do
      line = Engine.encode_info_line(
        version_string: "1.0.0",
        deps: [ [ "rack", ">= 1.0" ], [ "json", "~> 2.0" ] ],
        requirements: { checksum: "abc", ruby: ">= 3.0" }
      )
      assert_equal "1.0.0 rack:>= 1.0,json:~> 2.0|checksum:abc,ruby:>= 3.0\n", line
    end

    test "info_header is the literal '---' line" do
      assert_equal "---\n", Engine.info_header
    end
  end
end
