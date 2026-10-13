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

    def post_ledger_entry!(workspace, debit_ledger_account:, credit_ledger_account:, amount_kobo:, effective_date: Date.current, description: nil)
      ledger = workspace.ledgers.first ||
        workspace.provision_ledger!(template: workspace.ledger_template)
      command = Engine::Command.new(
        ledger: ledger,
        effective_date: effective_date,
        source_type: nil,
        source_id: nil,
        action: "create",
        description: description,
        lines: [
          Engine::Command::Line.new(ledger_account: debit_ledger_account, debit: amount_kobo, credit: 0),
          Engine::Command::Line.new(ledger_account: credit_ledger_account, debit: 0, credit: amount_kobo)
        ]
      )

      receipt = Engine.post(command)
      raise "Ledger entry rejected: #{receipt.errors.map(&:to_s).join(', ')}" unless receipt.success?

      receipt.entry
    end
  end
end
