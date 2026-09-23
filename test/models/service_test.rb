require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @income_account = @workspace.accounts.create!(name: "Service Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")
  end

  test "requires a unique name and income account" do
    @workspace.services.create!(name: "Interior design", income_account: @income_account)
    duplicate = @workspace.services.build(name: "Interior design", income_account: @income_account)
    missing = @workspace.services.build

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
    assert_not missing.valid?
    assert_includes missing.errors[:name], "can't be blank"
    assert_includes missing.errors[:income_account], "must exist"
  end

  test "rejects non-income and foreign workspace accounts" do
    expense = @workspace.accounts.create!(name: "Service Expense", base_type: "expense",
      account_type: "Personal Outflows", detail_type: "Transportation")
    foreign = workspaces(:bola_shop).accounts.create!(name: "Foreign Income", base_type: "income",
      account_type: "Personal Inflows", detail_type: "Side Hustle / Freelance")

    service = @workspace.services.build(name: "Invalid", income_account: expense)
    assert_not service.valid?
    assert_includes service.errors[:income_account], "must be an income account"

    service.income_account = foreign
    assert_not service.valid?
    assert_includes service.errors[:income_account], "must belong to the workspace"
  end

  test "stores the default rate in minor units" do
    service = @workspace.services.create!(name: "Design", income_account: @income_account, default_rate: "1250.75")

    assert_equal 125_075, service.default_rate_minor
    assert_equal BigDecimal("1250.75"), service.default_rate
  end
end
