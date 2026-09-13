require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
  end

  test "creates a customer" do
    assert_difference("Customer.count", 1) do
      post customers_path, params: {
        customer: {
          name: "Ada Supplies",
          customer_type: "business",
          email: "accounts@example.com",
          phone: "08000000000",
          address: "12 Market Road, Lagos",
          active: true
        }
      }
    end

    customer = @workspace.customers.order(:id).last
    assert_redirected_to customers_path
    assert_equal "business", customer.customer_type
    assert_equal "12 Market Road, Lagos", customer.address
  end

  test "deactivates a customer without deleting it" do
    customer = @workspace.customers.create!(name: "Ada", customer_type: "business", email: "ada@example.com")

    patch customer_path(customer), params: {
      customer: { name: customer.name, customer_type: customer.customer_type, email: customer.email, active: false }
    }

    assert_redirected_to customers_path
    assert_not customer.reload.active?
    assert Customer.exists?(customer.id)
  end

  test "cannot access another workspace customer" do
    customer = workspaces(:bola_shop).customers.create!(name: "Other", customer_type: "business", email: "other@example.com")

    get edit_customer_path(customer)

    assert_response :not_found
  end

  test "shows a customer without transaction history" do
    customer = @workspace.customers.create!(name: "Ada", customer_type: "single", email: "ada@example.com")

    get customer_path(customer)

    assert_response :success
    assert_select "h1", "Ada"
    assert_select "h2", text: "Transaction history", count: 0
  end

  test "cannot view another workspace customer" do
    customer = workspaces(:bola_shop).customers.create!(name: "Other", customer_type: "business", email: "other@example.com")

    get customer_path(customer)

    assert_response :not_found
  end
end
