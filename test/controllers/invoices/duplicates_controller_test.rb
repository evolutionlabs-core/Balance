require "test_helper"

class Invoices::DuplicatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    ledger = @workspace.provision_ledger!
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @service = @workspace.services.create!(name: "Consulting", income_account: ledger.accounts.find_by!(name: "Other Income"))
    sign_in_as(users(:one))
  end

  test "copies a sent invoice into a new draft dated today" do
    invoice = @workspace.invoices.create!(user: users(:one), customer: @customer, issue_date: Date.current - 40.days,
      payment_terms: "net_15", reference: "PO-1", notes: "Thanks", internal_note: "Private", payment_instructions: "GTBank",
      discount_type: "percent", discount_value: 10,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 2, rate: 150 } ])
    assert invoice.issue!

    assert_difference "@workspace.invoices.count", 1 do
      post invoice_duplicate_path(invoice)
    end

    copy = @workspace.invoices.order(:id).last
    assert_redirected_to edit_invoice_path(copy)
    assert copy.draft?
    assert_not_equal invoice.invoice_number, copy.invoice_number
    assert_equal [ @customer, Date.current, "net_15", Date.current + 15.days ], [ copy.customer, copy.issue_date, copy.payment_terms, copy.due_date ]
    assert_equal [ "Thanks", "GTBank", 27_000 ], [ copy.notes, copy.payment_instructions, copy.total_minor ]
    assert_nil copy.reference
    assert_nil copy.internal_note
    assert_equal [ [ @service.id, "Consulting", 30_000 ] ], copy.invoice_lines.map { |line| [ line.service_id, line.description, line.amount_minor ] }
  end

  test "custom terms fall back to the workspace default" do
    invoice = @workspace.invoices.create!(user: users(:one), customer: @customer, issue_date: Date.current, due_date: Date.current + 3.days,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 1, rate: 100 } ])

    post invoice_duplicate_path(invoice)

    copy = @workspace.invoices.order(:id).last
    assert_equal [ "net_30", Date.current + 30.days ], [ copy.payment_terms, copy.due_date ]
  end
end
