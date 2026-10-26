require "test_helper"

class Invoice::RevisionTest < ActiveSupport::TestCase
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

  test "changes the details of a sent invoice and logs what changed" do
    assert_no_difference -> { JournalEntry.count } do
      assert @invoice.revise({ "due_date" => "2026-11-15", "reference" => "PO-7", "bill_to_email" => "billing@acme.test" }, user: users(:one))
    end

    @invoice.reload
    assert_equal Date.new(2026, 11, 15), @invoice.due_date
    assert_equal "custom", @invoice.payment_terms
    assert_equal 30_000, @invoice.total_minor
    assert_equal [ 30_000 ], @invoice.invoice_lines.map(&:amount_minor)

    revision = @invoice.revisions.sole
    assert_equal users(:one), revision.user
    assert_equal @workspace, revision.workspace
    assert_equal({
      "due_date" => [ "2026-10-31", "2026-11-15" ],
      "payment_terms" => [ "net_30", "custom" ],
      "reference" => [ nil, "PO-7" ],
      "bill_to_email" => [ "acme@example.com", "billing@acme.test" ]
    }, revision.field_changes)
  end

  test "changing the terms recalculates the due date from the invoice date" do
    assert @invoice.revise({ "payment_terms" => "net_60" }, user: users(:one))

    assert_equal Date.new(2026, 11, 30), @invoice.reload.due_date
  end

  test "amounts stay locked" do
    assert @invoice.revise({ "discount_value" => "50", "notes" => "Thanks" }, user: users(:one))
    assert_equal 30_000, @invoice.reload.total_minor

    assert_not @invoice.update(discount_type: "amount", discount_value: 50)
    assert_includes @invoice.errors.full_messages, "Only the terms, due date, reference, billing email and notes can change after an invoice is sent"
    assert_equal 30_000, @invoice.reload.total_minor
  end

  test "an invalid billing email or an early due date is refused without logging" do
    assert_no_difference -> { InvoiceRevision.count } do
      assert_not @invoice.revise({ "bill_to_email" => "acme at example" }, user: users(:one))
      assert_includes @invoice.errors[:bill_to_email], "isn't a valid email address"

      assert_not @invoice.reload.revise({ "due_date" => "2026-09-30" }, user: users(:one))
      assert_includes @invoice.errors[:due_date], "can't be before the invoice date"
    end
  end

  test "saving without changes logs nothing" do
    assert_no_difference -> { InvoiceRevision.count } do
      assert @invoice.revise({ "reference" => "", "notes" => @invoice.notes }, user: users(:one))
    end
  end

  test "voided invoices stay fully locked" do
    assert @invoice.void!

    assert_not @invoice.revisable?
    assert_not @invoice.update(reference: "PO-7")
  end
end
