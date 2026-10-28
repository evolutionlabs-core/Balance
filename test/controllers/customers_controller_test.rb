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

  test "shows an invalid email under the email field" do
    assert_no_difference("Customer.count") do
      post customers_path, params: { customer: { name: "Ada Supplies", customer_type: "business", email: "accounts@example" } }
    end

    assert_response :unprocessable_content
    assert_select "#email_error", text: "Email isn't a valid email address"
    assert_select "input#customer_email[aria-invalid=true][aria-describedby=email_error]"
    assert_select "li", text: /Email/, count: 0
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

  test "index shows 20 customers per page" do
    customers = (1..21).map { |number| @workspace.customers.create!(name: format("Customer %02d", number), customer_type: "business", email: "customer#{number}@example.com") }

    get customers_path
    assert_select "tbody tr", count: 20
    assert_select "nav[aria-label=Pagination]", text: /1–20 of 21/
    assert_select "nav a[href=?]", "#{customers_path}?page=2", text: "Next"
    assert_select "nav a", text: "Previous", count: 0

    get customers_path(page: 2)
    assert_select "tbody tr", count: 1
    assert_select "tbody a[href=?]", customer_path(customers.last)
    assert_select "nav[aria-label=Pagination]", text: /21–21 of 21/
  end

  test "index shows pagination with both directions disabled when every customer fits on one page" do
    @workspace.customers.create!(name: "Ada", customer_type: "business", email: "ada@example.com")

    get customers_path

    assert_select "nav[aria-label=Pagination]", text: /\A\s*1–/ do
      assert_select "span[aria-disabled=true]", text: "Previous"
      assert_select "span[aria-disabled=true]", text: "Next"
      assert_select "a", count: 0
    end
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
