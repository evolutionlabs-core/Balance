require "test_helper"

class Invoices::CustomersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @customer = @workspace.contacts.create!(name: "Customer", email: "customer@example.com", contact_kind: "business", role_names: %w[customer])
    @invoice = @workspace.invoices.create!(contact: @customer, user: users(:one))
    sign_in_as(users(:one))
  end

  test "selects a customer and streams the saved billing details" do
    customer = @workspace.contacts.create!(name: "Customer", email: "customer@example.com", contact_kind: "business", role_names: %w[customer])
    patch invoice_customer_path(@invoice, contact_id: customer.id), headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal customer, @invoice.reload.contact
    assert_equal customer.email, @invoice.bill_to_email
    assert_equal customer.name, @invoice.bill_to_name
    assert_select "turbo-stream[target='#{dom_id(@invoice, :customer)}']"
    assert_select "input[name='invoice[contact_id]'], input[name='invoice[bill_to_name]']", count: 0
  end

  test "cannot select another workspace customer" do
    customer = workspaces(:bola_shop).contacts.create!(name: "Other", email: "other@example.com", contact_kind: "business", role_names: %w[customer])
    patch invoice_customer_path(@invoice, contact_id: customer.id), headers: { Accept: "text/vnd.turbo-stream.html" }
    assert_response :not_found
    assert_equal @customer, @invoice.reload.contact
  end
end
