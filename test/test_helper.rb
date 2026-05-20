ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Each test gets an isolated compact-index storage root so artifacts
    # written by one test never leak into another.
    setup do
      @compact_index_storage_root = Dir.mktmpdir("compact_index_test")
      CompactIndex.storage_root = @compact_index_storage_root
    end

    teardown do
      FileUtils.remove_entry(@compact_index_storage_root) if @compact_index_storage_root && File.exist?(@compact_index_storage_root)
      CompactIndex.storage_root = nil
    end
  end
end
