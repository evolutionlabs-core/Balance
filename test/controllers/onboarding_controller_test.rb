require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(full_name: "Nneka Obi", email_address: "nneka@example.com", password: "supersecret123")
    sign_in_as(@user)
  end

  test "provisions a personal NGN workspace with its ledger chart and no legacy accounts" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }
    assert_redirected_to onboarding_step_path(:details)

    assert_difference [ "Workspace.count", "Membership.count" ], 1 do
      patch onboarding_step_path(:details), params: { workspace_name: "Nneka's Money" }
    end

    workspace = @user.workspaces.last
    assert_equal "personal", workspace.workspace_type
    assert_equal "NGN", workspace.currency_code
    assert workspace.onboarding_completed_at?
    assert_empty workspace.journal_entries
    assert_empty workspace.accounts
    assert_equal "personal_finance", workspace.ledger_template
    assert_equal 18, workspace.ledgers.sole.ledger_accounts.count
    assert_redirected_to overview_path
  end

  test "posts a non-zero opening balance to the bank and opening balance equity through the engine" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }

    assert_difference "LedgerEntry.count", 1 do
      patch onboarding_step_path(:details), params: {
        workspace_name: "Nneka's Money",
        opening_balance_naira: "125000.50"
      }
    end

    workspace = @user.workspaces.last
    ledger = workspace.ledgers.sole
    entry = LedgerEntry.find_by!(source_type: "OpeningBalance", source_id: workspace.id)
    bank = ledger.ledger_accounts.find_by!(code: "1020")
    equity = ledger.ledger_accounts.find_by!(name: "Opening Balance Equity")

    assert_equal 12_500_050, entry.ledger_lines.find_by!(ledger_account: bank).debit
    assert_equal 12_500_050, entry.ledger_lines.find_by!(ledger_account: equity).credit
  end

  test "provisions a business workspace with the standard SME chart" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "business" }
    assert_redirected_to onboarding_step_path(:details)

    assert_difference [ "Workspace.count", "Membership.count" ], 1 do
      patch onboarding_step_path(:details), params: { workspace_name: "Nneka Limited" }
    end

    workspace = @user.workspaces.last
    assert_equal "business", workspace.workspace_type
    assert_equal "NGN", workspace.currency_code
    assert_equal "standard_sme", workspace.ledger_template
    assert_equal 24, workspace.ledgers.sole.ledger_accounts.count
    assert_redirected_to overview_path
  end

  test "rejects a negative opening balance" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }

    assert_no_difference("Workspace.count") do
      patch onboarding_step_path(:details), params: { workspace_name: "Nneka's Money", opening_balance_naira: "-1" }
    end

    assert_response :unprocessable_content
    assert_select "body", /Opening balance must be zero or more/
  end
end
