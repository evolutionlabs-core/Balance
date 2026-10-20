require "test_helper"

class AccountingEngine::Builders::InvoiceTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @income = @ledger.accounts.find_by!(name: "Other Income")
    @ar = @ledger.accounts.find_by!(name: "Accounts Receivable")
    @customer = @workspace.customers.create!(name: "Adapter Customer", customer_type: "business", email: "adapter@example.com")
  end

  test "issue debits receivable and credits each income line" do
    command = AccountingEngine::Builders::Invoice.call(
      workspace: @workspace,
      attributes: {
        action: "issue",
        effective_date: Date.current,
        customer: @customer,
        income_lines: [
          { account: @income, amount_kobo: 30_000 }
        ]
      },
      source_id: 7
    )

    assert_instance_of AccountingEngine::Command, command
    assert_equal @ledger, command.ledger
    assert_equal "Invoice", command.source_type
    assert_equal 7, command.source_id
    assert_equal "issue", command.action
    assert_equal Date.current, command.effective_date

    lines = command.lines
    assert_equal 2, lines.length
    ar_line = lines&.find { |line| line.debit.positive? }
    income_line = lines&.find { |line| line.credit.positive? }

    assert_equal @ar, ar_line.account
    assert_equal @customer, ar_line.customer
    assert_equal 30_000, ar_line.debit
    assert_equal @income, income_line.account
    assert_equal 30_000, income_line.credit
  end

  test "raises a readable error when no receivable account is provisioned" do
    @ar.delete

    error = assert_raises(AccountingEngine::Builders::AccountMissing) do
      AccountingEngine::Builders::Invoice.call(
        workspace: @workspace,
        attributes: { effective_date: Date.current, income_lines: [ { account: @income, amount_kobo: 100 } ] },
        source_id: 7
      )
    end

    assert_match /No Accounts Receivable account/, error.message
  end

  test "provisions the ledger on demand for a fresh workspace" do
    workspace = Workspace.create!(name: "Fresh Invoices", currency_code: "NGN")
    income = workspace.ledgers.first&.accounts&.find_by(name: "Other Income") ||
      workspace.provision_ledger!.accounts.find_by!(name: "Other Income")

    command = AccountingEngine::Builders::Invoice.call(
      workspace: workspace,
      attributes: { effective_date: Date.current, customer: nil, income_lines: [ { account: income, amount_kobo: 100 } ] },
      source_id: 1
    )

    assert_equal workspace.ledgers.first, command.ledger
  end
end

class AccountingEngine::Builders::InvoicePaymentTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @ar = @ledger.accounts.find_by!(name: "Accounts Receivable")
    @customer = @workspace.customers.create!(name: "Paying Customer", customer_type: "business", email: "paying@example.com")
  end

  test "apply debits the payment account and credits receivable" do
    command = AccountingEngine::Builders::InvoicePayment.call(
      workspace: @workspace,
      attributes: { received_on: Date.current, deposit_account_id: @cash.id, amount_kobo: 15_000, customer: @customer },
      source_id: 3
    )

    assert_equal "InvoicePayment", command.source_type
    assert_equal 3, command.source_id
    assert_equal Date.current, command.effective_date

    lines = command.lines
    assert_equal [ @cash, @ar ], lines.map(&:account)
    assert_equal [ nil, @customer ], lines.map(&:customer)
    assert_equal [ 15_000, 0 ], lines.map(&:debit)
    assert_equal [ 0, 15_000 ], lines.map(&:credit)
  end
end
