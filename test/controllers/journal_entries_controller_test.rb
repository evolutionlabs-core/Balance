require "test_helper"

class JournalEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!
  end

  test "lists journal entries with their journal entry lines" do
    cash = @ledger.accounts.find_by!(name: "Cash")
    groceries = @ledger.accounts.find_by!(name: "Groceries")
    entry = post_journal_entry!(
      @workspace,
      debit_account: groceries,
      credit_account: cash,
      amount_kobo: 100_00,
      description: "Weekly shop"
    )

    get journal_entries_path

    assert_response :success
    assert_select "tr##{dom_id(entry)}"
    assert_select "tr##{dom_id(entry)} td", text: /Groceries/
    assert_select "body", /Weekly shop/
    assert_select "body", /#{Regexp.escape("₦100.00")}/
  end

  test "shows an entry with its lines and links to it from the list" do
    cash = @ledger.accounts.find_by!(name: "Cash")
    groceries = @ledger.accounts.find_by!(name: "Groceries")
    entry = post_journal_entry!(@workspace, debit_account: groceries, credit_account: cash, amount_kobo: 100_00, description: "Weekly shop")

    get journal_entries_path
    assert_select "a[href=?]", journal_entry_path(entry), minimum: 1

    get journal_entry_path(entry)

    assert_response :success
    assert_select "h1", "Weekly shop"
    assert_select "tbody td", text: /Groceries/
    assert_select "tbody td", text: /Cash/
    assert_select "a[href=?]", new_journal_entry_reversal_path(entry), text: "Reverse"
  end

  test "an entry posted by a document links to it instead of offering a reversal" do
    cash = @ledger.accounts.find_by!(name: "Cash")
    groceries = @ledger.accounts.find_by!(name: "Groceries")
    expense = @workspace.expenses.create!(payment_account: cash, payment_date: Date.current, total_kobo: 100_00,
      expense_lines_attributes: [ { account: groceries, description: "Fuel", amount_kobo: 100_00, position: 0 } ])
    entry = AccountingEngine.post(AccountingEngine::Command.new(
      ledger: @ledger, effective_date: Date.current, source_type: "Expense", source_id: expense.id, action: "create",
      description: "Fuel", posted_by: users(:one),
      lines: [
        AccountingEngine::Command::Line.new(account: groceries, debit: 100_00, credit: 0),
        AccountingEngine::Command::Line.new(account: cash, debit: 0, credit: 100_00)
      ]
    )).entry

    get journal_entry_path(entry)

    assert_response :success
    assert_select "a[href=?]", expense_path(expense), text: "Expense"
    assert_select "a", text: "Reverse", count: 0
  end

  test "only shows entries in the current workspace" do
    other_ledger = provision_business_ledger!(workspaces(:bola_shop))
    accounts = other_ledger.accounts.where(base_type: "asset").first(2)
    other = post_journal_entry!(workspaces(:bola_shop), debit_account: accounts.first, credit_account: accounts.last, amount_kobo: 100)

    get journal_entry_path(other)

    assert_response :not_found
  end

  test "searches journal entries by description" do
    cash = @ledger.accounts.find_by!(name: "Cash")
    matching_entry = post_journal_entry!(
      @workspace,
      debit_account: @ledger.accounts.find_by!(name: "Groceries"),
      credit_account: cash,
      amount_kobo: 100_00,
      description: "Office lunch"
    )
    hidden_entry = post_journal_entry!(
      @workspace,
      debit_account: @ledger.accounts.find_by!(name: "Groceries"),
      credit_account: cash,
      amount_kobo: 200_00,
      description: "Opening balance"
    )

    get journal_entries_path(q: "lunch")

    assert_response :success
    assert_select "tr##{dom_id(matching_entry)}"
    assert_select "tr##{dom_id(hidden_entry)}", count: 0
  end

  test "searches journal entries by account" do
    cash = @ledger.accounts.find_by!(name: "Cash")
    matching_entry = post_journal_entry!(
      @workspace,
      debit_account: @ledger.accounts.find_by!(name: "Groceries"),
      credit_account: cash,
      amount_kobo: 100_00
    )
    hidden_entry = post_journal_entry!(
      @workspace,
      debit_account: @ledger.accounts.find_by!(name: "Housing"),
      credit_account: cash,
      amount_kobo: 200_00
    )

    get journal_entries_path(q: "Groceries")

    assert_response :success
    assert_select "tr##{dom_id(matching_entry)}"
    assert_select "tr##{dom_id(hidden_entry)}", count: 0
  end

  test "account selectors are searchable" do
    get new_journal_entry_path

    assert_response :success
    assert_select "[data-controller='select-menu'][data-select-menu-searchable-value='true']", count: 3
    assert_select "[data-controller='select-menu'][data-select-menu-search-in-trigger-value='true'] input[role='combobox']", count: 3
  end

  test "added lines get their own index in the posted params" do
    get new_journal_entry_path

    assert_response :success
    assert_select "template input[name='entry[lines][__INDEX__][debit]']"
    assert_select "template input[name='entry[lines][__INDEX__][credit]']"
  end
end
