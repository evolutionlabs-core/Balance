require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(full_name: "Nneka Obi", email_address: "nneka@example.com", password: "supersecret123")
    sign_in_as(@user)
  end

  test "provisions a personal NGN workspace with every core account" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }
    assert_redirected_to onboarding_step_path(:details)

    assert_difference [ "Workspace.count", "Membership.count" ], 1 do
      assert_difference "Account.count", AccountCatalogs::Personal.core.size do
        patch onboarding_step_path(:details), params: { workspace_name: "Nneka's Money" }
      end
    end

    workspace = @user.workspaces.last
    assert_equal "personal", workspace.workspace_type
    assert_equal "NGN", workspace.currency_code
    assert workspace.onboarding_completed_at?
    assert_empty workspace.journal_entries
    assert_equal AccountCatalogs::Personal.core.keys.map(&:to_s).sort,
                 workspace.accounts.order(:role).pluck(:role)
    assert_redirected_to overview_path
  end

  test "posts a non-zero opening balance to checking and opening balance equity" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }

    assert_difference "JournalEntry.count", 1 do
      patch onboarding_step_path(:details), params: {
        workspace_name: "Nneka's Money",
        opening_balance_naira: "125000.50"
      }
    end

    workspace = @user.workspaces.last
    entry = workspace.journal_entries.last

    assert_equal "Opening balance", entry.description
    assert_equal 12_500_050, entry.journal_entry_lines.find_by!(account: Account.for_role!(workspace, :checking)).debit_kobo
    assert_equal 12_500_050, entry.journal_entry_lines.find_by!(account: Account.for_role!(workspace, :opening_balance)).credit_kobo
  end

  test "rejects a negative opening balance" do
    patch onboarding_step_path(:workspace_type), params: { workspace_type: "personal" }

    assert_no_difference "Workspace.count" do
      patch onboarding_step_path(:details), params: { workspace_name: "Nneka's Money", opening_balance_naira: "-1" }
    end

    assert_response :unprocessable_content
    assert_select "body", /Opening balance must be zero or more/
  end

  test "business selection remains unavailable" do
    assert_no_difference "Workspace.count" do
      patch onboarding_step_path(:workspace_type), params: { workspace_type: "business" }
    end

    assert_response :unprocessable_content
    assert_select "body", /coming soon/i
  end
end
