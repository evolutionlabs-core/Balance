require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
    Ledgers::Provisioner.call(workspace: @workspace, template: "personal_finance")
  end

  test "lists the workspace ledger chart in code order" do
    get accounts_path

    assert_response :success
    assert_select "body", /Checking Account/
    codes = css_select("tbody tr td:first-child").map(&:text)
    assert_equal codes.sort, codes
  end

  test "shows a lock for system accounts" do
    ledger = @workspace.ledgers.sole
    system_account = ledger.ledger_accounts.find_by!(name: "Opening Balance Equity")

    get accounts_path

    assert_select "tr##{dom_id(system_account)} [title='System account — locked']"
  end

  test "does not list another workspace ledger" do
    other = workspaces(:bola_shop)
    Ledgers::Provisioner.call(workspace: other, template: "standard_sme")

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

  test "requires authentication" do
    delete session_path
    get accounts_path

    assert_redirected_to new_session_path
  end
end
