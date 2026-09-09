ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/llm_chat_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def post_journal_entry!(workspace, debit_account:, credit_account:, amount_kobo:, entry_date: Date.current, description: "Test entry")
      workspace.journal_entries.create!(
        description: description,
        entry_date: entry_date,
        journal_entry_lines_attributes: [
          { account_id: debit_account.id, debit_kobo: amount_kobo },
          { account_id: credit_account.id, credit_kobo: amount_kobo }
        ]
      )
    end
  end
end
