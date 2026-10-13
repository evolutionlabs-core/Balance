require "test_helper"

class Engine::Adapters::InvoiceTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @income = @ledger.ledger_accounts.find_by!(name: "Other Income")
    @ar = @ledger.ledger_accounts.find_by!(name: "Accounts Receivable")
  end

  test "issue debits receivable and credits each income line" do
    command = Engine::Adapters::Invoice.call(
      workspace: @workspace,
      attributes: {
        action: "issue",
        effective_date: Date.current,
        income_lines: [
          { ledger_account: @income, amount_kobo: 30_000 }
        ]
      },
      source_id: 7
    )

    assert_instance_of Engine::Command, command
    assert_equal @ledger, command.ledger
    assert_equal "Invoice", command.source_type
    assert_equal 7, command.source_id
    assert_equal "issue", command.action
    assert_equal Date.current, command.effective_date

    lines = command.lines
    assert_equal 2, lines.length
    ar_line = lines&.find { |line| line.debit.positive? }
    income_line = lines&.find { |line| line.credit.positive? }

    assert_equal @ar, ar_line.ledger_account
    assert_equal 30_000, ar_line.debit
    assert_equal @income, income_line.ledger_account
    assert_equal 30_000, income_line.credit
  end

  test "void mirrors the issue entry" do
    command = Engine::Adapters::Invoice.call(
      workspace: @workspace,
      attributes: {
        action: "void",
        effective_date: Date.current,
        income_lines: [ { ledger_account: @income, amount_kobo: 30_000 } ]
      },
      source_id: 7
    )

    lines = command.lines
    assert_equal @ar, lines&.find { |line| line.credit.positive? }.ledger_account
    assert_equal 30_000, lines&.find { |line| line.credit.positive? }.credit
    assert_equal @income, lines&.find { |line| line.debit.positive? }.ledger_account
    assert_equal 30_000, lines&.find { |line| line.debit.positive? }.debit
  end

  test "raises a readable error when no receivable account is provisioned" do
    @ar.destroy!

    error = assert_raises(ActiveRecord::RecordNotFound) do
      Engine::Adapters::Invoice.call(
        workspace: @workspace,
        attributes: { action: "issue", effective_date: Date.current, income_lines: [ { ledger_account: @income, amount_kobo: 100 } ] },
        source_id: 7
      )
    end

    assert_match /No Accounts Receivable account/, error.message
  end

  test "provisions the ledger on demand for a fresh workspace" do
    workspace = Workspace.create!(name: "Fresh Invoices", currency_code: "NGN")
    income = workspace.ledgers.first&.ledger_accounts&.find_by(name: "Other Income") ||
      workspace.provision_ledger!(template: workspace.ledger_template).ledger_accounts.find_by!(name: "Other Income")

    command = Engine::Adapters::Invoice.call(
      workspace: workspace,
      attributes: { action: "issue", effective_date: Date.current, income_lines: [ { ledger_account: income, amount_kobo: 100 } ] },
      source_id: 1
    )

    assert_equal workspace.ledgers.first, command.ledger
  end
end

class Engine::Adapters::InvoicePaymentTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    @ar = @ledger.ledger_accounts.find_by!(name: "Accounts Receivable")
  end

  test "apply debits the payment account and credits receivable" do
    command = Engine::Adapters::InvoicePayment.call(
      workspace: @workspace,
      attributes: { received_on: Date.current, payment_ledger_account_id: @cash.id, amount_kobo: 15_000 },
      source_id: 3
    )

    assert_equal "InvoicePayment", command.source_type
    assert_equal 3, command.source_id
    assert_equal Date.current, command.effective_date

    lines = command.lines
    assert_equal [ @cash, @ar ], lines.map(&:ledger_account)
    assert_equal [ 15_000, 0 ], lines.map(&:debit)
    assert_equal [ 0, 15_000 ], lines.map(&:credit)
  end

  test "reverse mirrors the application entry" do
    command = Engine::Adapters::InvoicePayment.call(
      workspace: @workspace,
      attributes: { action: "reverse", received_on: Date.current, payment_ledger_account_id: @cash.id, amount_kobo: 15_000 },
      source_id: 4
    )

    assert_equal "reverse", command.action
    lines = command.lines
    assert_equal [ @ar, @cash ], lines.map(&:ledger_account)
    assert_equal [ 15_000, 0 ], lines.map(&:debit)
    assert_equal [ 0, 15_000 ], lines.map(&:credit)
  end
end
