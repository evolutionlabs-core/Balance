require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(full_name: "Nneka Obi", email_address: "nneka@example.com", password: "supersecret123")
    sign_in_as(@user)
  end

  test "provisions a personal NGN workspace with its ledger chart" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }
    assert_redirected_to onboarding_step_path(:details)

    assert_difference [ "Workspace.count", "Membership.count" ], 1 do
      patch onboarding_step_path(:details), params: { workspace_name: "Nneka's Money", currency_code: "NGN" }
    end

    workspace = @user.workspaces.last
    assert_equal "personal", workspace.workspace_type
    assert_equal "NGN", workspace.currency_code
    assert workspace.onboarding_completed_at?
    assert workspace.ledger.accounts.exists?(key: "salary")
    assert_equal 18, workspace.ledgers.sole.accounts.count
    assert_redirected_to overview_path
  end

  test "posts a non-zero opening balance to the bank and opening balance equity through the engine" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }

    assert_difference "JournalEntry.count", 1 do
      patch onboarding_step_path(:details), params: {
        workspace_name: "Nneka's Money",
        currency_code: "NGN",
        opening_balance: "125000.50"
      }
    end

    workspace = @user.workspaces.last
    ledger = workspace.ledgers.sole
    entry = JournalEntry.find_by!(source_type: "OpeningBalance", source_id: workspace.id)
    bank = ledger.accounts.find_by!(code: "1020")
    equity = ledger.accounts.find_by!(name: "Opening Balance Equity")

    assert_equal 12_500_050, entry.journal_entry_lines.find_by!(account: bank).debit
    assert_equal 12_500_050, entry.journal_entry_lines.find_by!(account: equity).credit
  end

  test "provisions a business workspace with the standard SME chart" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "business" }
    assert_redirected_to onboarding_step_path(:details)

    assert_difference [ "Workspace.count", "Membership.count" ], 1 do
      patch onboarding_step_path(:details), params: { workspace_name: "Nneka Limited", currency_code: "NGN" }
    end

    workspace = @user.workspaces.last
    assert_equal "business", workspace.workspace_type
    assert_equal "NGN", workspace.currency_code
    assert workspace.ledger.accounts.exists?(key: "sales")
    assert_equal 24, workspace.ledgers.sole.accounts.count
    assert_redirected_to overview_path
  end

  test "rejects a negative opening balance" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }

    assert_no_difference("Workspace.count") do
      patch onboarding_step_path(:details), params: { workspace_name: "Nneka's Money", currency_code: "NGN", opening_balance: "-1" }
    end

    assert_response :unprocessable_content
    assert_select "body", /Opening balance must be zero or more/
  end

  test "creates a workspace in the chosen currency, ledger included" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "business" }
    patch onboarding_step_path(:details), params: { workspace_name: "Accra Studio", currency_code: "GHS", opening_balance: "500" }

    workspace = @user.workspaces.last
    assert_equal "GHS", workspace.currency_code
    assert_equal "GHS", workspace.ledger.currency_code
    assert_equal 50_000, JournalEntry.find_by!(source_type: "OpeningBalance", source_id: workspace.id).journal_entry_lines.sum(:debit)
  end

  test "rejects an unsupported currency" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }

    assert_no_difference "Workspace.count" do
      patch onboarding_step_path(:details), params: { workspace_name: "Tokyo", currency_code: "JPY" }
    end

    assert_response :unprocessable_content
    assert_select "body", /Choose a currency for your workspace/
  end

  test "stores the month the financial year starts" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "business" }
    patch onboarding_step_path(:details), params: { workspace_name: "April Books", currency_code: "NGN", fiscal_year_start_month: "4" }

    assert_equal 4, @user.workspaces.last.fiscal_year_start_month
  end
end
