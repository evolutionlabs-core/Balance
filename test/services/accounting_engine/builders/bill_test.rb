require "test_helper"

class AccountingEngine::Builders::BillTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:chidi_supplies)
    @ledger = @workspace.provision_ledger!
    @rent = @ledger.accounts.find_by!(key: "rent")
    @inventory = @ledger.accounts.find_by!(key: "inventory")
    @ap = @ledger.accounts.find_by!(key: "accounts_payable")
    @vendor = @workspace.vendors.create!(name: "Adapter Vendor")
  end

  test "issue debits each expense line and credits payables" do
    command = AccountingEngine::Builders::Bill.call(
      workspace: @workspace,
      attributes: {
        effective_date: Date.current,
        vendor: @vendor,
        expense_lines: [
          { account: @rent, amount_kobo: 50_000 },
          { account: @inventory, amount_kobo: 20_000 }
        ]
      },
      source_id: 9
    )

    assert_equal "Bill", command.source_type
    assert_equal "issue", command.action
    assert_equal 9, command.source_id

    lines = command.lines
    assert_equal 3, lines.length
    assert_equal 50_000, lines.find { |line| line.account == @rent }.debit
    assert_equal 20_000, lines.find { |line| line.account == @inventory }.debit
    ap_line = lines.find { |line| line.account == @ap }
    assert_equal @vendor, ap_line.vendor
    assert_equal 70_000, ap_line.credit
    assert_equal 0, ap_line.debit
  end

  test "raises a readable error when no payables account is provisioned" do
    @ap.delete

    error = assert_raises(AccountingEngine::Builders::AccountMissing) do
      AccountingEngine::Builders::Bill.call(
        workspace: @workspace,
        attributes: { effective_date: Date.current, vendor: @vendor, expense_lines: [ { account: @rent, amount_kobo: 100 } ] },
        source_id: 9
      )
    end

    assert_match "No Accounts Payable account", error.message
  end
end
