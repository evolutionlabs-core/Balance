require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
    @income_account = @ledger.ledger_accounts.find_by!(name: "Other Income")
  end

  test "requires a unique name and an income ledger account" do
    @workspace.services.create!(name: "Interior design", income_ledger_account: @income_account)
    duplicate = @workspace.services.build(name: "Interior design", income_ledger_account: @income_account)
    missing = @workspace.services.build

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
    assert_not missing.valid?
    assert_includes missing.errors[:name], "can't be blank"
    assert_includes missing.errors[:income_ledger_account], "must exist"
  end

  test "rejects non-income and foreign-workspace ledger accounts" do
    expense = @ledger.ledger_accounts.find_by!(name: "Groceries")
    foreign_ledger = workspaces(:bola_shop).provision_ledger!(template: "standard_sme")
    foreign = foreign_ledger.ledger_accounts.find_by!(name: "Sales")

    service = @workspace.services.build(name: "Invalid", income_ledger_account: expense)
    assert_not service.valid?
    assert_includes service.errors[:income_ledger_account], "must be an income account"

    service.income_ledger_account = foreign
    assert_not service.valid?
    assert_includes service.errors[:income_ledger_account], "must belong to the workspace"
  end

  test "stores the default rate in minor units" do
    service = @workspace.services.create!(name: "Design", income_ledger_account: @income_account, default_rate: "1250.75")

    assert_equal 125_075, service.default_rate_minor
    assert_equal BigDecimal("1250.75"), service.default_rate
  end
end
