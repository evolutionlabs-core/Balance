require "test_helper"

class Invoices::ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    @contact = @workspace.contacts.create!(name: "Customer", contact_kind: "business", email: "old@example.com", role_names: %w[customer])
    @invoice = @workspace.invoices.create!(user: @user, contact: @contact)
    sign_in_as(@user)
  end

  test "updates the contact and refreshes the saved invoice customer" do
    patch invoice_contact_path(@contact, invoice_id: @invoice.id), params: {
      contact: {
        name: "Updated Customer", contact_kind: "business", email: "new@example.com",
        address: "12 Broad Street", role_names: %w[customer]
      }
    }, headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_select "turbo-stream[action='replace'][target='#{dom_id(@invoice, :customer)}']"
    assert_equal "Updated Customer", @invoice.reload.bill_to_name
    assert_equal "12 Broad Street", @invoice.bill_to_address
  end

  test "updates a customer and returns unsaved invoice fields" do
    assert_no_difference "Invoice.count" do
      patch invoice_contact_path(@contact), params: {
        contact: {
          name: "Updated Customer", contact_kind: "business", email: "new@example.com",
          address: "12 Broad Street", role_names: %w[customer]
        }
      }, headers: { Accept: "text/vnd.turbo-stream.html" }
    end

    assert_select "turbo-stream[action='replace'][target='customer_invoice']"
    assert_select "turbo-stream[action='replace'][target='new_invoice_submission']"
  end
end
