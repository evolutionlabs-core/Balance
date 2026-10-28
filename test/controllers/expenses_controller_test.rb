require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @workspace.provision_ledger!
    @ledger = @workspace.ledgers.first
    @bank = @ledger.accounts.find_by!(name: "Checking Account")
    @housing = @ledger.accounts.find_by!(name: "Housing")
  end

  test "creates the expense and its journal entry through the engine" do
    assert_difference -> { Expense.count } => 1, -> { JournalEntry.count } => 1, -> { JournalEntryLine.count } => 2 do
      post expenses_path, params: expense_params
    end

    expense = @workspace.expenses.order(:id).last
    entry = expense.journal_entry

    assert_redirected_to expense_path(expense)
    assert expense.reload.posted?
    assert_equal @workspace.ledgers.first, entry.ledger
    assert_equal expense.payment_date, entry.effective_date
    assert_equal [ "Expense", expense.id, "create" ], entry.values_at(:source_type, :source_id, :action)
    assert_equal [ [ "Housing", 4_000_000, 0 ], [ "Checking Account", 0, 4_000_000 ] ],
      entry.journal_entry_lines.map { |line| [ line.account.name, line.debit, line.credit ] }
  end

  test "creates nothing when the expense is invalid" do
    params = expense_params
    params[:expense][:expense_lines_attributes]["0"][:amount] = "3ooo"

    assert_no_difference("Expense.count") { post expenses_path, params: params }
    assert_no_difference("JournalEntry.count") { post expenses_path, params: params }

    assert_response :unprocessable_content
  end

  test "creates nothing when a category is outside the workspace ledger" do
    other_workspace = workspaces(:bola_shop)
    other_ledger = provision_business_ledger!(other_workspace)
    foreign = other_ledger.accounts.find_by!(name: "Rent")
    params = expense_params
    params[:expense][:expense_lines_attributes]["0"][:account_id] = foreign.id

    assert_no_difference("Expense.count") { post expenses_path, params: params }
    assert_no_difference("JournalEntry.count") { post expenses_path, params: params }

    assert_response :unprocessable_content
  end

  test "creates nothing and surfaces the message when the engine rejects the posting" do
    @workspace.ledger.update!(status: "archived")

    assert_no_difference -> { Expense.count } do
      assert_no_difference -> { JournalEntry.count } do
        post expenses_path, params: expense_params
      end
    end

    assert_response :unprocessable_content
    assert_match "Ledger General is archived", response.body
  end

  test "renders the show page for an expense posted through the engine" do
    post expenses_path, params: expense_params
    expense = @workspace.expenses.order(:id).last

    get expense_path(expense)

    assert_response :success
    assert_match "Checking Account", response.body
  end

  test "carries the expense description onto the journal entry" do
    params = expense_params
    params[:expense][:memo] = "Team lunch"

    post expenses_path, params: params

    assert_equal "Team lunch", @workspace.expenses.order(:id).last.journal_entry.description
  end

  test "falls back to category descriptions when the expense has no memo" do
    post expenses_path, params: expense_params

    assert_equal "Rent", @workspace.expenses.order(:id).last.journal_entry.description
  end

  test "index shows 20 expenses per page" do
    expenses = (1..21).map { |number| record_expense(format("Stadium rent %02d", number)) }

    get expenses_path
    assert_select "tbody tr", count: 20
    assert_select "nav[aria-label=Pagination]", text: /1–20 of 21/
    assert_select "nav a[href=?]", "#{expenses_path}?page=2", text: "Next"
    assert_select "nav a", text: "Previous", count: 0

    get expenses_path(page: 2)
    assert_select "tbody tr", count: 1
    assert_select "tr##{dom_id(expenses.first)}"
    assert_select "nav[aria-label=Pagination]", text: /21–21 of 21/
  end

  test "index shows pagination with both directions disabled when every expense fits on one page" do
    record_expense("Stadium rent")

    get expenses_path

    assert_select "nav[aria-label=Pagination]", text: /\A\s*1–/ do
      assert_select "span[aria-disabled=true]", text: "Previous"
      assert_select "span[aria-disabled=true]", text: "Next"
      assert_select "a", count: 0
    end
  end

  test "cannot access another workspace expense" do
    other_workspace = workspaces(:bola_shop)
    other_ledger = provision_business_ledger!(other_workspace)
    expense = other_workspace.expenses.create!(
      payment_date: Date.current,
      payment_account: other_ledger.accounts.find_by!(name: "Bank"),
      expense_lines_attributes: [ { account: other_ledger.accounts.find_by!(name: "Rent"), description: "Rent", amount_kobo: 1_000, position: 0 } ]
    )

    get expense_path(expense)

    assert_response :not_found
  end

  private
    def record_expense(memo)
      expense = @workspace.expenses.build(payment_date: Date.current, payment_account: @bank, memo: memo)
      expense.expense_lines.build(account: @housing, description: memo, amount_kobo: 10_000_00, position: 0)
      expense.record_entry!
      expense
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
