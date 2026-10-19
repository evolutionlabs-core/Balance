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
end
