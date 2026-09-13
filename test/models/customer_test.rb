require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
  end

  test "requires a single or business customer type" do
    customer = @workspace.customers.build(name: "Ada", email: "ada@example.com")

    assert_not customer.valid?
    assert_includes customer.errors[:customer_type], "can't be blank"
  end

  test "rejects an unknown customer type" do
    customer = @workspace.customers.build(name: "Ada", email: "ada@example.com", customer_type: "vendor")

    assert_not customer.valid?
    assert_includes customer.errors[:customer_type], "is not included in the list"
  end

  test "requires an email" do
    customer = @workspace.customers.build(name: "Ada", customer_type: "single")

    assert_not customer.valid?
    assert_includes customer.errors[:email], "can't be blank"
  end

  test "orders customers by name" do
    @workspace.customers.create!(name: "Zara", customer_type: "single", email: "zara@example.com")
    ada = @workspace.customers.create!(name: "Ada", customer_type: "business", email: "ada@example.com")

    assert_equal [ ada.name, "Zara" ], @workspace.customers.ordered.pluck(:name)
  end
end
