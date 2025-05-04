ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "fileutils"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Create test storage directory for attachments
    setup do
      # Create test storage path if it doesn't exist
      test_storage_path = Rails.root.join('storage', 'attachments')
      FileUtils.mkdir_p(test_storage_path) unless Dir.exist?(test_storage_path)
    end

    # Add more helper methods to be used by all tests here...
  end
end
