require "test_helper"

class Invoices::InteractionsTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @headers = { Accept: "text/vnd.turbo-stream.html" }
  end

  test "calculations and row changes never persist an invoice or line" do
    attributes = { invoice: { currency_code: "NGN", invoice_lines_attributes: {
      "0" => { description: "First", quantity: 2, rate: 150 },
      "123456789" => { description: "Added", quantity: 1, rate: 50 }
    } } }

    assert_no_difference [ "Invoice.count", "InvoiceLine.count" ] do
      post invoice_calculation_path, params: attributes, headers: @headers
      assert_response :success
      assert_select "turbo-stream[target='invoice_total'] template", text: "NGN 350.00"
      get new_invoice_line_path, headers: @headers
      assert_response :success
      assert_select "turbo-stream[action='append'][target='invoice_lines']"
      delete invoice_line_path("0"), params: attributes, headers: @headers
      assert_response :success
      assert_select "turbo-stream[action='remove'][target='new_invoice_line_0']"
      assert_select "turbo-stream[target='invoice_total'] template", text: "NGN 50.00"
    end
  end

  test "customer selection renders details without persisting a new invoice" do
    customer = @workspace.contacts.create!(name: "New Customer", email: "customer@example.com", contact_kind: "business", role_names: %w[customer])

    assert_no_difference "Invoice.count" do
      get invoice_contact_path(customer), headers: @headers
    end

    assert_response :success
    assert_select "input[name='invoice[bill_to_email]'][value='customer@example.com']"
    assert_select "button[name='invoice[contact_id]'][value=?]", customer.id
  end

  test "customer selection cannot read another workspace contact" do
    customer = workspaces(:bola_shop).contacts.create!(name: "Other", email: "other@example.com", contact_kind: "business", role_names: %w[customer])
    get invoice_contact_path(customer), headers: @headers
    assert_response :not_found
  end
end
