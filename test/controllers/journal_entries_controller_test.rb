require "test_helper"

class JournalEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = @workspace.provision_ledger!(template: "personal_finance")
  end

  test "lists ledger entries with their ledger lines" do
    cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    groceries = @ledger.ledger_accounts.find_by!(name: "Groceries")
    entry = post_ledger_entry!(
      @workspace,
      debit_ledger_account: groceries,
      credit_ledger_account: cash,
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

  test "searches ledger entries by description" do
    cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    matching_entry = post_ledger_entry!(
      @workspace,
      debit_ledger_account: @ledger.ledger_accounts.find_by!(name: "Groceries"),
      credit_ledger_account: cash,
      amount_kobo: 100_00,
      description: "Office lunch"
    )
    hidden_entry = post_ledger_entry!(
      @workspace,
      debit_ledger_account: @ledger.ledger_accounts.find_by!(name: "Groceries"),
      credit_ledger_account: cash,
      amount_kobo: 200_00,
      description: "Opening balance"
    )

    get journal_entries_path(q: "lunch")

    assert_response :success
    assert_select "tr##{dom_id(matching_entry)}"
    assert_select "tr##{dom_id(hidden_entry)}", count: 0
  end

  test "searches ledger entries by account" do
    cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    matching_entry = post_ledger_entry!(
      @workspace,
      debit_ledger_account: @ledger.ledger_accounts.find_by!(name: "Groceries"),
      credit_ledger_account: cash,
      amount_kobo: 100_00
    )
    hidden_entry = post_ledger_entry!(
      @workspace,
      debit_ledger_account: @ledger.ledger_accounts.find_by!(name: "Housing"),
      credit_ledger_account: cash,
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
    cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    groceries = @ledger.ledger_accounts.find_by!(name: "Groceries")

    assert_difference "LedgerEntry.count", 1 do
      post journal_entries_path, params: { entry: {
        effective_date: Date.current.to_s,
        description: "Manual shop",
        lines: {
          "0" => { ledger_account_id: groceries.id, debit: "1000.00", credit: "" },
          "1" => { ledger_account_id: cash.id, debit: "", credit: "1000.00" }
        }
      } }
    end

    assert_redirected_to journal_entries_path

    entry = @ledger.ledger_entries.sole
    assert_equal "Manual shop", entry.description
    assert_equal "Entry", entry.source_type
    assert_nil entry.source_id

    groceries_line = entry.ledger_lines.find_by(debit: 100_000)
    assert_equal groceries, groceries_line&.ledger_account
  end

  test "rejects an unbalanced manual entry" do
    cash = @ledger.ledger_accounts.find_by!(name: "Cash")
    groceries = @ledger.ledger_accounts.find_by!(name: "Groceries")

    assert_no_difference "LedgerEntry.count" do
      post journal_entries_path, params: { entry: {
        effective_date: Date.current.to_s,
        description: "Unbalanced",
        lines: {
          "0" => { ledger_account_id: groceries.id, debit: "1000.00", credit: "" },
          "1" => { ledger_account_id: cash.id, debit: "", credit: "500.00" }
        }
      } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Total debits (100000.0) must equal total credits (50000.0)"
  end
end
