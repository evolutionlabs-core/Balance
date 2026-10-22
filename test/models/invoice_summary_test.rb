require "test_helper"

class InvoiceSummaryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @customer = @workspace.customers.create!(name: "Acme", email: "acme@example.com", customer_type: "business")
    @service = @workspace.services.create!(name: "Consulting", income_account: @ledger.accounts.find_by!(name: "Other Income"))
    @cash = @ledger.accounts.find_by!(name: "Cash")
  end

  test "splits outstanding balances into overdue and not due" do
    overdue = issued_invoice(due_date: Date.current - 3.days, rate: 100)
    issued_invoice(due_date: Date.current, rate: 250)
    create_draft(rate: 999)
    assert overdue.record_payment!(deposit_account_id: @cash.id, received_on: Date.current, amount_kobo: 4_000)

    summary = InvoiceSummary.new(@workspace)

    assert_equal [ 1, 6_000 ], [ summary.overdue.count, summary.overdue.amount_kobo ]
    assert_equal [ 1, 25_000 ], [ summary.not_due.count, summary.not_due.amount_kobo ]
  end

  test "totals payments received in the last 30 days" do
    invoice = issued_invoice(due_date: Date.current + 30.days, rate: 500)
    assert invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current - 5.days, amount_kobo: 10_000)
    assert invoice.record_payment!(deposit_account_id: @cash.id, received_on: Date.current - 45.days, amount_kobo: 7_000)

    assert_equal 10_000, InvoiceSummary.new(@workspace).paid_recently_kobo
  end

  private
    def issued_invoice(due_date:, rate:)
      invoice = @workspace.invoices.create!(user: users(:one), customer: @customer, issue_date: Date.current - 60.days, due_date: due_date,
        invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 1, rate: rate } ])
      assert invoice.issue!
      invoice
    end

    def create_draft(rate:)
      @workspace.invoices.create!(user: users(:one), customer: @customer, due_date: Date.current - 10.days,
        invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 1, rate: rate } ])
    end
end
