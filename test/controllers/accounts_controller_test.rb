require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    @ledger = @workspace.provision_ledger!
  end

  test "lists the workspace ledger chart in code order" do
    get accounts_path

    assert_response :success
    assert_select "body", /Checking Account/
    codes = css_select("tbody tr td:first-child").map(&:text)
    assert_equal codes.sort, codes
  end

  test "shows a lock for system accounts" do
    system_account = @ledger.accounts.find_by!(name: "Opening Balance Equity")

    get accounts_path

    assert_response :success
    assert_select "tr##{dom_id(system_account)} [title='System account — locked']"
  end

  test "hides the edit link from the index" do
    get accounts_path

    assert_response :success
    assert_select "a", text: "Edit", count: 0
  end

  test "does not list another workspace ledger" do
    other = workspaces(:bola_shop)
    provision_business_ledger!(other)

    get accounts_path

    assert_response :success
    assert_select "body", { text: /Bank/, count: 0 }
  end

  test "renders an empty state when the workspace has no ledger" do
    empty = Workspace.create!(name: "Empty", currency_code: "NGN")
    empty.memberships.create!(user: @user, role: :owner)
    Current.session.update!(workspace: empty)

    get accounts_path

    assert_response :success
    assert_select "body", /No accounts yet/
  end

  test "renders the new account form" do
    get new_account_path

    assert_response :success
    assert_select "turbo-frame#modal"
    assert_select "select#account_base_type option", text: "Asset"
    assert_select "select#account_base_type option", text: "Expense"
  end

  test "derives the normal balance from the base type on create" do
    post accounts_path, params: { account: {
      code: "1035", name: "GTBank Savings", base_type: "asset", subtype: "cash"
    } }

    assert_equal "debit", @ledger.accounts.find_by!(code: "1035").normal_balance
    assert_redirected_to accounts_path
  end

  test "cannot edit a template account" do
    template_account = @ledger.accounts.find_by!(name: "Housing")

    get edit_account_path(template_account)
    assert_response :not_found

    patch account_path(template_account), params: { account: { name: "Hijacked" } }
    assert_response :not_found
    assert_equal "Housing", template_account.reload.name
  end

  test "cannot edit another workspace account" do
    other = workspaces(:bola_shop)
    provision_business_ledger!(other)
    foreign = other.ledgers.sole.accounts.find_by!(name: "Bank")

    patch account_path(foreign), params: { account: { name: "Hijacked" } }

    assert_response :not_found
    assert_not_equal "Hijacked", foreign.reload.name
  end
end
