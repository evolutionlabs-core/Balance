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

  test "records a manual entry through the ledger engine" do
    cash = @ledger.accounts.find_by!(name: "Cash")
    groceries = @ledger.accounts.find_by!(name: "Groceries")

    assert_difference "JournalEntry.count", 1 do
      post journal_entries_path, params: { entry: {
        effective_date: Date.current.to_s,
        description: "Manual shop",
        lines: {
          "0" => { account_id: groceries.id, debit: "1000.00", credit: "" },
          "1" => { account_id: cash.id, debit: "", credit: "1000.00" }
        }
      } }
    end

    assert_redirected_to journal_entries_path

    entry = @ledger.journal_entries.sole
    assert_equal "Manual shop", entry.description
    assert_equal "Entry", entry.source_type
    assert_nil entry.source_id

    groceries_line = entry.journal_entry_lines.find_by(debit: 100_000)
    assert_equal groceries, groceries_line&.account
  end

  test "rejects an unbalanced manual entry" do
    cash = @ledger.accounts.find_by!(name: "Cash")
    groceries = @ledger.accounts.find_by!(name: "Groceries")

    assert_no_difference "JournalEntry.count" do
      post journal_entries_path, params: { entry: {
        effective_date: Date.current.to_s,
        description: "Unbalanced",
        lines: {
          "0" => { account_id: groceries.id, debit: "1000.00", credit: "" },
          "1" => { account_id: cash.id, debit: "", credit: "500.00" }
        }
      } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Total debits (1000.00) must equal total credits (500.00)"
  end

  test "a malformed amount is a form error, not a crash" do
    cash = @ledger.accounts.find_by!(name: "Cash")
    groceries = @ledger.accounts.find_by!(name: "Groceries")

    assert_no_difference "JournalEntry.count" do
      post journal_entries_path, params: { entry: {
        effective_date: Date.current.to_s,
        description: "Typo",
        lines: {
          "0" => { account_id: groceries.id, debit: "1.2.3", credit: "" },
          "1" => { account_id: cash.id, debit: "", credit: "-50" }
        }
      } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Line 1: enter amounts as positive numbers, like 1,250.00"
  end
end
