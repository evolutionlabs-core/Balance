require "test_helper"

class Invoice::DetailsTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @workspace.provision_ledger!
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @invoice = @workspace.invoices.create!(
      user: users(:one), customer: @customer, issue_date: Date.new(2026, 10, 1), payment_terms: "net_30",
      invoice_lines_attributes: [ { description: "Consulting", quantity: 2, rate: 150 } ]
    )
    assert @invoice.issue!
  end

  test "changes the details of a sent invoice without touching its amounts or the books" do
    assert_no_difference -> { JournalEntry.count } do
      assert @invoice.revise({ "due_date" => "2026-11-15", "reference" => "PO-7", "bill_to_email" => "billing@acme.test" })
    end

    @invoice.reload
    assert_equal Date.new(2026, 11, 15), @invoice.due_date
    assert_equal "custom", @invoice.payment_terms
    assert_equal "PO-7", @invoice.reference
    assert_equal "billing@acme.test", @invoice.bill_to_email
    assert_equal 30_000, @invoice.total_minor
    assert_equal [ 30_000 ], @invoice.invoice_lines.map(&:amount_minor)
  end

  test "changing the terms recalculates the due date from the invoice date" do
    assert @invoice.revise({ "payment_terms" => "net_60" })

    assert_equal Date.new(2026, 11, 30), @invoice.reload.due_date
  end

  test "amounts stay locked" do
    assert @invoice.revise({ "discount_value" => "50", "notes" => "Thanks" })
    assert_equal 30_000, @invoice.reload.total_minor

    assert_not @invoice.update(discount_type: "amount", discount_value: 50)
    assert_includes @invoice.errors.full_messages, "Only the terms, due date, reference, billing email and notes can change after an invoice is sent"
    assert_equal 30_000, @invoice.reload.total_minor
  end

  test "details only change through the edit details form" do
    assert_not @invoice.update(reference: "PO-7")
    @customer.update!(email: "accounts@acme.test")
    assert_raises(ActiveRecord::RecordNotSaved) { @invoice.reload.change_customer(@customer) }

    assert_nil @invoice.reload.reference
    assert_equal "acme@example.com", @invoice.bill_to_email
  end

  test "an invalid billing email or an early due date is refused" do
    assert_not @invoice.revise({ "bill_to_email" => "acme at example" })
    assert_includes @invoice.errors[:bill_to_email], "isn't a valid email address"

    assert_not @invoice.reload.revise({ "due_date" => "2026-09-30" })
    assert_includes @invoice.errors[:due_date], "can't be before the invoice date"
    assert_equal Date.new(2026, 10, 31), @invoice.reload.due_date
  end

  test "voided invoices stay fully locked" do
    assert @invoice.void!

    assert_not @invoice.revisable?
    assert_not @invoice.update(reference: "PO-7")
  end
end
