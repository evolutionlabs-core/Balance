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

    def provision_business_ledger!(workspace)
      workspace.update!(workspace_type: "business")
      workspace.provision_ledger!
    end

    def post_journal_entry!(workspace, debit_account:, credit_account:, amount_kobo:, effective_date: Date.current, description: nil)
      ledger = workspace.ledgers.first || workspace.provision_ledger!
      command = Accounting::Command.new(
        ledger: ledger,
        effective_date: effective_date,
        source_type: nil,
        source_id: nil,
        action: "create",
        description: description,
        lines: [
          Accounting::Command::Line.new(account: debit_account, debit: amount_kobo, credit: 0),
          Accounting::Command::Line.new(account: credit_account, debit: 0, credit: amount_kobo)
        ]
      )

      receipt = Accounting.post(command)
      raise "Journal entry rejected: #{receipt.errors.map(&:to_s).join(', ')}" unless receipt.success?

      receipt.entry
    end
  end
end
