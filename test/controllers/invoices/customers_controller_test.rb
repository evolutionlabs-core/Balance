require "test_helper"

class Invoices::CustomersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @customer = @workspace.customers.create!(name: "Customer", customer_type: "business", email: "old@example.com")
    @invoice = @workspace.invoices.create!(user: @user, customer: @customer)
    sign_in_as(@user)
  end

  test "updates the customer and refreshes the saved invoice customer" do
    patch invoice_customer_path(@customer, invoice_id: @invoice.id), params: {
      customer: {
        name: "Updated Customer", customer_type: "business", email: "new@example.com",
        address: "12 Broad Street"
      }
    }, headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_select "turbo-stream[action='replace'][target='#{dom_id(@invoice, :customer)}']"
    assert_equal "Updated Customer", @invoice.reload.bill_to_name
    assert_equal "12 Broad Street", @invoice.bill_to_address
  end

  test "updates a customer and returns unsaved invoice fields" do
    assert_no_difference "Invoice.count" do
      patch invoice_customer_path(@customer), params: {
        customer: {
          name: "Updated Customer", customer_type: "business", email: "new@example.com",
          address: "12 Broad Street"
        }
      }, headers: { Accept: "text/vnd.turbo-stream.html" }
    end

    assert_select "turbo-stream[action='replace'][target='customer_invoice']"
    assert_select "turbo-stream[action='replace'][target='new_invoice_submission']"
  end
end
