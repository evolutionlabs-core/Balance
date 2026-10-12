require "test_helper"

class JournalEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    sign_in_as(users(:one))
    @ledger = Ledgers::Provisioner.call(workspace: @workspace, template: "personal_finance")
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
end
