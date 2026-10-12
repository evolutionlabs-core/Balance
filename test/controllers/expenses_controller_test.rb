require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    Ledgers::Provisioner.call(workspace: @workspace, template: "personal_finance")
    @bank = create_account(name: "Checking Account", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    @housing = create_account(name: "Housing", base_type: "expense", account_type: "Personal Outflows", detail_type: "Housing & Utilities")
  end

  test "creates the expense and its ledger entry through the engine" do
    assert_difference -> { Expense.count } => 1, -> { LedgerEntry.count } => 1, -> { LedgerLine.count } => 2 do
      post expenses_path, params: expense_params
    end

    expense = @workspace.expenses.order(:id).last
    entry = expense.ledger_entry

    assert_redirected_to expense_path(expense)
    assert expense.reload.posted?
    assert_equal @workspace.ledgers.first, entry.ledger
    assert_equal expense.payment_date, entry.effective_date
    assert_equal [ "Expense", expense.id, "create" ], entry.values_at(:source_type, :source_id, :action)
    assert_equal [ [ "Housing", 4_000_000, 0 ], [ "Checking Account", 0, 4_000_000 ] ],
      entry.ledger_lines.map { |line| [ line.ledger_account.name, line.debit, line.credit ] }
  end

  test "creates nothing when the expense is invalid" do
    params = expense_params
    params[:expense][:expense_lines_attributes]["0"][:amount] = "3ooo"

    assert_no_difference("Expense.count") { post expenses_path, params: params }
    assert_no_difference("LedgerEntry.count") { post expenses_path, params: params }

    assert_response :unprocessable_content
  end

  test "creates nothing when the engine rejects the command" do
    stale = create_account(name: "Fuel", base_type: "expense", account_type: "Personal Outflows", detail_type: "Transportation")
    merged = {
      expense: expense_params[:expense].merge(expense_lines_attributes: {
        "0" => { account_id: stale.id, description: "Fuel", amount: "40000.00", position: 0 }
      })
    }

    assert_no_difference("Expense.count") { post expenses_path, params: merged }
    assert_no_difference("LedgerEntry.count") { post expenses_path, params: merged }

    assert_response :unprocessable_content
  end

  test "creates nothing and surfaces the message when a block rule rejects the command" do
    Rule.create!(name: "block rule", severity: "block", message: "blocked by policy")

    assert_no_difference -> { Expense.count } do
      assert_no_difference -> { LedgerEntry.count } do
        post expenses_path, params: expense_params
      end
    end

    assert_response :unprocessable_content
    assert_match "blocked by policy", response.body
  end

  test "renders the show page for an expense posted through the engine" do
    post expenses_path, params: expense_params
    expense = @workspace.expenses.order(:id).last

    get expense_path(expense)

    assert_response :success
    assert_match "Checking Account", response.body
  end

  test "cannot access another workspace expense" do
    other_workspace = workspaces(:bola_shop)
    other_bank = other_workspace.accounts.create!(name: "Bank", base_type: "asset", account_type: "Cash & Liquid Assets", detail_type: "Checking Account")
    other_category = other_workspace.accounts.create!(name: "Food", base_type: "expense", account_type: "Personal Outflows", detail_type: "Living & Daily Needs")
    expense = other_workspace.expenses.create!(
      payment_date: Date.current,
      payment_account: other_bank,
      expense_lines_attributes: [ { account: other_category, description: "Food", amount_kobo: 1_000, position: 0 } ]
    )

    get expense_path(expense)

    assert_response :not_found
  end

  private
    def create_account(**attributes)
      @workspace.accounts.create!(attributes)
    end

    def expense_params
      {
        expense: {
          payment_date: Date.current,
          payment_account_id: @bank.id,
          expense_lines_attributes: {
            "0" => { account_id: @housing.id, description: "Rent", amount: "40000.00", position: 0 }
          }
        }
      }
    end
end
