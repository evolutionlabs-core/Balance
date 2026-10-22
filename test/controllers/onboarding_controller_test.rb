require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(full_name: "Nneka Obi", email_address: "nneka@example.com", password: "supersecret123")
    sign_in_as(@user)
  end

  test "provisions a personal NGN workspace with its ledger chart" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }
    assert_redirected_to onboarding_step_path(:details)

    patch onboarding_step_path(:details), params: { workspace_name: "Nneka's Money", currency_code: "NGN" }
    assert_redirected_to onboarding_step_path(:balances)

    assert_difference [ "Workspace.count", "Membership.count" ], 1 do
      assert_no_difference "JournalEntry.count" do
        patch onboarding_step_path(:balances)
      end
    end

    workspace = @user.workspaces.last
    assert_equal "personal", workspace.workspace_type
    assert_equal "NGN", workspace.currency_code
    assert workspace.onboarding_completed_at?
    assert workspace.ledger.accounts.exists?(key: "salary")
    assert_equal 18, workspace.ledgers.sole.accounts.count
    assert_redirected_to overview_path
  end

  test "provisions a business workspace with the standard SME chart by default" do
    complete_details(type: "business", name: "Nneka Limited")
    patch onboarding_step_path(:balances)

    workspace = @user.workspaces.last
    assert_equal "business", workspace.workspace_type
    assert workspace.ledger.accounts.exists?(key: "inventory")
    assert_equal 24, workspace.ledgers.sole.accounts.count
  end

  test "a services business starts without stock accounts" do
    complete_details(type: "business", name: "Nneka Consulting", template: "services")

    get onboarding_step_path(:balances)
    assert_select "input[name='balances[inventory]']", count: 0
    assert_select "input[name='balances[bank]']"

    patch onboarding_step_path(:balances)

    accounts = @user.workspaces.last.ledger.accounts
    assert_equal 22, accounts.count
    assert_not accounts.exists?(key: "inventory")
    assert_not accounts.exists?(key: "cost_of_goods_sold")
  end

  test "personal workspaces get no template choice" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }

    get onboarding_step_path(:details)

    assert_select "select[name=template]", count: 0
  end

  test "posts opening balances per account through the engine" do
    complete_details(type: "business", name: "Nneka Limited")

    assert_difference "JournalEntry.count", 1 do
      patch onboarding_step_path(:balances), params: { opening_balance_date: 3.days.ago.to_date.iso8601,
        balances: { bank: "125,000.50", cash: "", credit_card: "20000", loan_payable: "50000" } }
    end

    workspace = @user.workspaces.last
    entry = workspace.ledger.journal_entries.sole
    accounts = workspace.ledger.accounts.index_by(&:key)
    assert_equal [ "OpeningBalance", workspace.id, "create" ], entry.values_at(:source_type, :source_id, :action)
    assert_equal 3.days.ago.to_date, entry.effective_date
    assert_equal({ accounts["bank"].id => [ 12_500_050, 0 ], accounts["credit_card"].id => [ 0, 2_000_000 ],
      accounts["loan_payable"].id => [ 0, 5_000_000 ], accounts["opening_balance_equity"].id => [ 0, 5_500_050 ] },
      entry.journal_entry_lines.to_h { |line| [ line.account_id, [ line.debit, line.credit ] ] })
  end

  test "keeps typed balances when an amount is invalid" do
    complete_details(type: "personal", name: "Nneka's Money")

    assert_no_difference "Workspace.count" do
      patch onboarding_step_path(:balances), params: { balances: { bank: "-1", cash: "300" } }
    end

    assert_response :unprocessable_content
    assert_select "body", /Enter the Checking Account balance as a positive number/
    assert_select "input[name='balances[cash]'][value='300']"
  end

  test "rejects an opening date in the future" do
    complete_details(type: "personal", name: "Nneka's Money")

    assert_no_difference "Workspace.count" do
      patch onboarding_step_path(:balances), params: { opening_balance_date: Date.tomorrow.iso8601, balances: { bank: "10" } }
    end

    assert_response :unprocessable_content
    assert_select "body", /isn't in the future/
  end

  test "creates a workspace in the chosen currency, ledger included" do
    complete_details(type: "business", name: "Accra Studio", currency: "GHS")
    patch onboarding_step_path(:balances), params: { balances: { bank: "500" } }

    workspace = @user.workspaces.last
    assert_equal "GHS", workspace.currency_code
    assert_equal "GHS", workspace.ledger.currency_code
    assert_equal 50_000, workspace.ledger.journal_entries.sole.journal_entry_lines.sum(:debit)
  end

  test "rejects an unsupported currency and keeps the balances step locked" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }

    patch onboarding_step_path(:details), params: { workspace_name: "Tokyo", currency_code: "JPY" }

    assert_response :unprocessable_content
    assert_select "body", /Choose a currency for your workspace/
    assert_select "input[name=workspace_name][value=Tokyo]"

    get onboarding_step_path(:balances)
    assert_redirected_to onboarding_step_path(:details)
  end

  test "stores the month the financial year starts" do
    complete_details(type: "business", name: "April Books", fiscal_year_start_month: "4")
    patch onboarding_step_path(:balances)

    assert_equal 4, @user.workspaces.last.fiscal_year_start_month
  end

  private
    def complete_details(type:, name:, currency: "NGN", **extra)
      patch onboarding_step_path(:workspace_type), params: { workspace_type: type }
      patch onboarding_step_path(:details), params: { workspace_name: name, currency_code: currency, **extra }
      assert_redirected_to onboarding_step_path(:balances)
    end
end
