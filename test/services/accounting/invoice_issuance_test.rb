require "test_helper"

class Accounting::InvoiceIssuanceTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @customer = @workspace.customers.create!(
      name: "Issuance Customer",
      customer_type: "business",
      email: "issuance@example.com"
    )
    Account.for_role!(@workspace, :receivable)
    @income = @workspace.accounts.create!(
      name: "Issuance Income",
      base_type: "income",
      account_type: "Personal Inflows",
      detail_type: "Side Hustle / Freelance"
    )
    @service = @workspace.services.create!(name: "Issuance service", income_account: @income)
  end

  test "rolls back account snapshots when persistence rejects the plan" do
    invoice = @workspace.invoices.create!(
      user: @user,
      customer: @customer,
      invoice_lines_attributes: [ { service: @service, description: "Work", quantity: 1, rate_minor: 500 } ]
    )
    invoice.invoice_lines.sole.update_column(:account_id, nil)
    rejecting_service = Object.new
    rejecting_service.define_singleton_method(:call) do |entry:, source:|
      Accounting::PostingService::Result.new(entry, [ "Ledger rejected the plan" ], nil)
    end

    assert_no_difference([ "JournalEntry.count", "JournalEntryLine.count" ]) do
      result = Accounting::InvoiceIssuance.call(invoice:, posting_service: rejecting_service)

      assert_not result.success?
      assert_equal [ "Ledger rejected the plan" ], result.errors
    end
    assert_nil invoice.reload.invoice_lines.sole.account_id
    assert invoice.draft?
    assert_nil invoice.journal_entry_id
  end
end
