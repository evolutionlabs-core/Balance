require "test_helper"

class Invoices::PreviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    ledger = @workspace.provision_ledger!
    @customer = @workspace.customers.create!(name: "Acme", customer_type: "business", email: "acme@example.com")
    @service = @workspace.services.create!(name: "Consulting", income_account: ledger.accounts.find_by!(name: "Other Income"))
    sign_in_as(users(:one))
  end

  test "previews a new invoice without saving it" do
    assert_no_difference "Invoice.count" do
      post invoice_preview_path, params: { invoice: { customer_id: @customer.id, notes: "Thanks",
        invoice_lines_attributes: { "0" => { description: "Design", quantity: 2, rate: 100 } } } }
    end

    assert_response :success
    assert_select "turbo-frame#invoice_preview" do
      assert_select "td", text: "Design"
      assert_select "dd", text: "NGN 200.00"
      assert_select "p", text: "Acme"
      assert_select "p", text: "Thanks"
    end
  end

  test "previews unsaved changes to a draft and leaves it unchanged" do
    invoice = @workspace.invoices.create!(user: users(:one), customer: @customer, issue_date: Date.current,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 1, rate: 100 } ])
    line = invoice.invoice_lines.sole

    post invoice_preview_path(invoice_id: invoice.id), params: { invoice: {
      invoice_lines_attributes: { "-#{line.id}" => { description: "Consulting", quantity: 3, rate: 100 }, "1" => { description: "Travel", quantity: 1, rate: 50 } } } }

    assert_select "dd", text: "NGN 350.00"
    assert_select "td", text: "Travel"
    assert_equal [ 10_000, 1 ], [ invoice.reload.total_minor, invoice.invoice_lines.count ]
  end

  test "does not preview sent invoices" do
    invoice = @workspace.invoices.create!(user: users(:one), customer: @customer, issue_date: Date.current,
      invoice_lines_attributes: [ { service_id: @service.id, description: "Consulting", quantity: 1, rate: 100 } ])
    assert invoice.issue!

    post invoice_preview_path(invoice_id: invoice.id), params: { invoice: { notes: "Changed" } }

    assert_response :not_found
  end
end
