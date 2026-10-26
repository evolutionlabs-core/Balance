require "test_helper"

class Invoices::DetailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @workspace.provision_ledger!
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @invoice = @workspace.invoices.create!(
      user: users(:one), customer: @customer, issue_date: Date.current, payment_terms: "net_30",
      invoice_lines_attributes: [ { description: "Consulting", quantity: 2, rate: 150 } ]
    )
    assert @invoice.issue!
  end

  test "the form explains that amounts are locked and links to a credit note" do
    get edit_invoice_details_path(@invoice)

    assert_response :success
    assert_select "p", text: /Amounts are locked after sending/
    assert_select "a[href=?]", new_invoice_credit_note_path(@invoice), text: "credit note"
    assert_select "input[name='invoice[due_date]']"
    assert_select "input[name='invoice[total_minor]']", count: 0
  end

  test "saves the details" do
    patch invoice_details_path(@invoice), params: { invoice: { due_date: (Date.current + 45).iso8601, reference: "PO-7" } }

    assert_redirected_to invoice_path(@invoice)
    @invoice.reload
    assert_equal "PO-7", @invoice.reference
    assert_equal Date.current + 45, @invoice.due_date
  end

  test "an invalid billing email is shown on the field" do
    patch invoice_details_path(@invoice), params: { invoice: { bill_to_email: "acme at example" } }

    assert_response :unprocessable_content
    assert_select "#bill_to_email_error", text: "Bill to email isn't a valid email address"
    assert_equal "acme@example.com", @invoice.reload.bill_to_email
  end

  test "drafts are edited in the full editor instead" do
    draft = @workspace.invoices.create!(user: users(:one), customer: @customer,
      invoice_lines_attributes: [ { description: "Consulting", quantity: 1, rate: 100 } ])

    get edit_invoice_details_path(draft)

    assert_redirected_to invoice_path(draft)
  end
end
