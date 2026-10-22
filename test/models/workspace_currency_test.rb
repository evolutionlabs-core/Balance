require "test_helper"

class WorkspaceCurrencyTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @workspace = Workspace.create_for_user!(user: @user, name: "Nairobi Works", workspace_type: "business", currency_code: "KES")
    @customer = @workspace.customers.create!(name: "Client", customer_type: "business", email: "client@example.com")
  end

  test "documents take the workspace currency whatever the form sends" do
    project = @workspace.projects.create!(name: "Site", customer: @customer, currency_code: "NGN")
    invoice = @workspace.invoices.create!(user: @user, customer: @customer, currency_code: "NGN")
    bill = @workspace.bills.create!(user: @user, vendor: @workspace.vendors.create!(name: "Supplier"), currency_code: "NGN",
      bill_date: Date.current, bill_lines_attributes: [ { account_id: @workspace.expense_categories.first.id, description: "Paper", amount: "10.00" } ])
    estimate = @workspace.estimates.create!(user: @user, customer: @customer, project: project)

    assert_equal %w[KES KES KES KES], [ project, invoice, bill, estimate ].map(&:currency_code)
  end

  test "a document can't drift away from the workspace currency" do
    invoice = @workspace.invoices.create!(user: @user, customer: @customer)

    assert_not invoice.update(currency_code: "USD")
    assert_includes invoice.errors[:currency_code], "must be the workspace currency (KES)"
  end

  test "a workspace's currency can't change once created" do
    assert_not @workspace.update(currency_code: "USD")
    assert_equal "KES", @workspace.reload.currency_code
    assert_not Workspace.new(name: "Yen", currency_code: "JPY").valid?
  end

  test "amount input accepts any supported currency prefix" do
    assert_equal 125_050, MoneyInput.to_kobo("KSh 1,250.50")
    assert_equal 125_050, MoneyInput.to_kobo("$1250.50")
    assert_equal 125_050, MoneyInput.to_kobo("GH₵1250.50")
    assert_equal 125_050, MoneyInput.to_kobo("USD 1250.50")
    assert_nil MoneyInput.to_kobo("abc1250")
  end
end
