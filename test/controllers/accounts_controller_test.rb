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

  test "archives an unused account, hides it from pickers and restores it" do
    marketing = @ledger.accounts.create!(code: "5700", name: "Billboards", base_type: "expense", subtype: "marketing")

    post account_archival_path(marketing)
    assert_redirected_to accounts_path
    assert_not marketing.reload.active?

    get accounts_path
    assert_select "tr##{dom_id(marketing)}", count: 0
    get accounts_path(archived: "1")
    assert_select "tr##{dom_id(marketing)}"
    assert_not_includes @workspace.expense_categories, marketing
    get new_expense_path
    assert_select "option", text: "Billboards", count: 0

    delete account_archival_path(marketing)
    assert_redirected_to accounts_path(archived: "1")
    assert marketing.reload.active?
    assert_includes @workspace.expense_categories, marketing
  end

  test "won't archive an account that still has a balance or a system account" do
    cash = @ledger.accounts.find_by!(name: "Cash")
    salary = @ledger.accounts.find_by!(name: "Salary")
    post_journal_entry!(@workspace, debit_account: cash, credit_account: salary, amount_kobo: 1_000)

    post account_archival_path(cash)
    assert_redirected_to accounts_path
    assert_match "still has a balance", flash[:alert]
    assert cash.reload.active?

    equity = @ledger.accounts.find_by!(key: "opening_balance_equity")
    post account_archival_path(equity)
    assert_match "system account", flash[:alert]
    assert equity.reload.active?
  end

  test "the engine refuses entries to an archived account" do
    unused = @ledger.accounts.create!(code: "5701", name: "Old Expense", base_type: "expense", subtype: "other_expense")
    unused.archive
    cash = @ledger.accounts.find_by!(name: "Cash")

    receipt = AccountingEngine.post(AccountingEngine::Command.new(ledger: @ledger, effective_date: Date.current, lines: [
      AccountingEngine::Command::Line.new(account: unused, debit: 100, credit: 0),
      AccountingEngine::Command::Line.new(account: cash, debit: 0, credit: 100)
    ]))

    assert_not receipt.success?
    assert_match "inactive", receipt.errors.map(&:to_s).join
  end

  test "searches accounts by name or code and shows balances" do
    cash = @ledger.accounts.find_by!(name: "Cash")
    post_journal_entry!(@workspace, debit_account: cash, credit_account: @ledger.accounts.find_by!(name: "Salary"), amount_kobo: 250_000)

    get accounts_path(q: "cash")
    assert_select "tbody tr", count: 1
    assert_select "tr##{dom_id(cash)} td", text: "₦2,500.00"
    assert_select "tr##{dom_id(cash)} a[href=?]", general_ledger_account_path(cash)

    get accounts_path(q: cash.code)
    assert_select "tr##{dom_id(cash)}"
  end

  test "only archives accounts in the current workspace" do
    other = provision_business_ledger!(workspaces(:bola_shop)).accounts.find_by!(key: "marketing")

    post account_archival_path(other)

    assert_response :not_found
    assert other.reload.active?
  end
end
