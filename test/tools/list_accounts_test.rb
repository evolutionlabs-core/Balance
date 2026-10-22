require "test_helper"

class ListAccountsTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
  end

  test "returns existing accounts with balances and remaining chart recommendations" do
    @ledger.accounts.find_by!(name: "Housing").destroy
    post_journal_entry!(
      @workspace,
      debit_account: @cash,
      credit_account: @ledger.accounts.find_by!(name: "Other Income"),
      amount_kobo: 12_400
    )

    result = ListAccounts.new(@workspace).execute(purpose: "Receive salary")

    assert_equal "Receive salary", result[:purpose]
    assert_includes result[:selection_guidance], "final economic substance"
    assert_includes result[:selection_guidance], "transferred amount plus the fee"

    existing = result[:existing_accounts]
    cash_row = existing.find { |account| account[:id] == @cash.id }
    assert_equal "Cash", cash_row[:name]
    assert_equal "1010", cash_row[:code]
    assert_equal 12_400, cash_row[:balance_kobo]

    recommended = result[:recommended_accounts]
    assert_includes recommended, {
      name: "Housing", code: "5010", base_type: "expense", subtype: "housing"
    }
    refute_includes recommended.map { |account| account[:name] }, "Cash"

    expense_taxonomy = result[:account_taxonomy].find { |category| category[:base_type] == "expense" }
    assert_includes expense_taxonomy[:subtypes], "housing"
    assert_includes expense_taxonomy[:subtypes], "groceries"
  end

  test "drops recommended chart accounts that already exist" do
    @ledger.accounts.find_by!(name: "Housing").destroy
    @ledger.accounts.create!(
      name: "Housing",
      base_type: "expense",
      subtype: "housing",
      code: "9510",
      created_by: "admin"
    )

    result = ListAccounts.new(@workspace).execute(purpose: "Receive salary")

    assert_empty result[:recommended_accounts]
    assert_includes result[:existing_accounts].map { |account| account[:name] }, "Housing"
  end
end
