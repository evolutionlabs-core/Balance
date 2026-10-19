require "test_helper"

class AgedBalancesTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @sales = @ledger.accounts.find_by!(key: "sales")
    @bank = @ledger.accounts.find_by!(key: "bank")
    @rent = @ledger.accounts.find_by!(key: "rent")
    @acme = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @zenith = @workspace.customers.create!(name: "Zenith", customer_type: "business", email: "zenith@example.com")
    @landlord = @workspace.vendors.create!(name: "Lagos Landlords")
  end

  test "buckets open invoices by days past due and ties out to receivables" do
    send_invoice(@acme, naira: 1_000, due_date: 10.days.from_now.to_date)
    send_invoice(@acme, naira: 400, due_date: 45.days.ago.to_date)
    overdue = send_invoice(@zenith, naira: 300, due_date: 100.days.ago.to_date)
    assert overdue.record_payment!(payment_account_id: @bank.id, received_on: Date.current, amount_kobo: 10_000)

    aging = AgedBalances.new(@workspace, side: :receivables)

    acme, zenith = aging.rows
    assert_equal @acme, acme.counterparty
    assert_equal 100_000, acme.buckets[:current]
    assert_equal 40_000, acme.buckets[:days_31_60]
    assert_equal 140_000, acme.total_kobo
    assert_equal 20_000, zenith.buckets[:over_90]
    assert_equal 160_000, aging.total_kobo
    assert_equal 160_000, aging.ledger_kobo
    assert aging.tied_out?
  end

  test "drops paid and voided invoices" do
    paid = send_invoice(@acme, naira: 500, due_date: Date.current)
    assert paid.record_payment!(payment_account_id: @bank.id, received_on: Date.current, amount_kobo: 50_000)
    assert send_invoice(@zenith, naira: 200, due_date: Date.current).void!

    aging = AgedBalances.new(@workspace, side: :receivables)

    assert_empty aging.rows
    assert aging.tied_out?
  end

  test "buckets open bills and ties out to payables" do
    bill = @workspace.bills.create!(user: users(:three), vendor: @landlord, bill_date: 20.days.ago.to_date, due_date: 5.days.ago.to_date,
      bill_lines_attributes: [ { account_id: @rent.id, description: "Office rent", amount: "750.00" } ])
    assert bill.issue!

    aging = AgedBalances.new(@workspace, side: :payables)

    row = aging.rows.sole
    assert_equal @landlord, row.counterparty
    assert_equal 75_000, row.buckets[:days_1_30]
    assert_equal 75_000, aging.ledger_kobo
    assert aging.tied_out?
  end

  test "reports a control-account balance no document explains" do
    send_invoice(@acme, naira: 1_000, due_date: Date.current)
    receivable = @ledger.accounts.find_by!(key: "accounts_receivable")
    entry = @ledger.journal_entries.create!(number: 99, effective_date: Date.current, description: "Posted around the subledger")
    entry.journal_entry_lines.create!(account: receivable, debit: 5_000, credit: 0)
    entry.journal_entry_lines.create!(account: @sales, debit: 0, credit: 5_000)

    aging = AgedBalances.new(@workspace, side: :receivables)

    refute aging.tied_out?
    unassigned = aging.unmatched_rows.sole
    assert_nil unassigned.counterparty
    assert_equal 5_000, unassigned.ledger_kobo
    assert_equal 0, unassigned.total_kobo
  end

  private
    def send_invoice(customer, naira:, due_date:)
      invoice = @workspace.invoices.create!(
        user: users(:three), customer: customer, issue_date: Date.current, due_date: due_date,
        invoice_lines_attributes: [ { account_id: @sales.id, description: "Supplies", quantity: 1, rate: naira } ]
      )
      assert invoice.issue!, invoice.errors.full_messages.to_sentence
      invoice
    end
end
