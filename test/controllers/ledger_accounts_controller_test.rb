require "test_helper"

class LedgerAccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    @ledger = Ledgers::Provisioner.call(workspace: @workspace, template: "personal_finance")
  end

  test "lists the workspace ledger chart in code order" do
    get ledger_accounts_path

    assert_response :success
    assert_select "body", /Checking Account/
    codes = css_select("tbody tr td:first-child").map(&:text)
    assert_equal codes.sort, codes
  end

  test "shows a lock for system accounts" do
    system_account = @ledger.ledger_accounts.find_by!(name: "Opening Balance Equity")

    get ledger_accounts_path

    assert_response :success
    assert_select "tr##{dom_id(system_account)} [title='System account — locked']"
  end

  test "hides the edit link from the index" do
    get ledger_accounts_path

    assert_response :success
    assert_select "a", text: "Edit", count: 0
  end

  test "does not list another workspace ledger" do
    other = workspaces(:bola_shop)
    Ledgers::Provisioner.call(workspace: other, template: "standard_sme")

    get ledger_accounts_path

    assert_response :success
    assert_select "body", { text: /Bank/, count: 0 }
  end

  test "renders an empty state when the workspace has no ledger" do
    empty = Workspace.create!(name: "Empty", currency_code: "NGN")
    empty.memberships.create!(user: @user, role: :owner)
    Current.session.update!(workspace: empty)

    get ledger_accounts_path

    assert_response :success
    assert_select "body", /No accounts yet/
  end

  test "renders the new account form" do
    get new_ledger_account_path

    assert_response :success
    assert_select "turbo-frame#modal"
    assert_select "select#ledger_account_base_type option", text: "Asset"
    assert_select "select#ledger_account_base_type option", text: "Expense"
  end

  test "derives the normal balance from the base type on create" do
    post ledger_accounts_path, params: { ledger_account: {
      code: "1035", name: "GTBank Savings", base_type: "asset", subtype: "cash"
    } }

    assert_equal "debit", @ledger.ledger_accounts.find_by!(code: "1035").normal_balance
    assert_redirected_to ledger_accounts_path
  end

  test "cannot edit a template account" do
    template_account = @ledger.ledger_accounts.find_by!(name: "Housing")

    get edit_ledger_account_path(template_account)
    assert_response :not_found

    patch ledger_account_path(template_account), params: { ledger_account: { name: "Hijacked" } }
    assert_response :not_found
    assert_equal "Housing", template_account.reload.name
  end

  test "cannot edit another workspace ledger account" do
    other = workspaces(:bola_shop)
    Ledgers::Provisioner.call(workspace: other, template: "standard_sme")
    foreign = other.ledgers.sole.ledger_accounts.find_by!(name: "Bank")

    patch ledger_account_path(foreign), params: { ledger_account: { name: "Hijacked" } }

    assert_response :not_found
    assert_not_equal "Hijacked", foreign.reload.name
  end
end
