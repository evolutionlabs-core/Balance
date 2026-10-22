require "test_helper"

class Workspace::CreationTest < ActiveSupport::TestCase
  test "creates a personal workspace with the personal finance chart" do
    user = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")

    workspace = Workspace.create_for_user!(
      user: user,
      name: "Ife's Finances",
      workspace_type: "personal",
      currency_code: "NGN"
    )

    assert_equal user, workspace.memberships.owner.first.user

    ledger = workspace.ledgers.sole
    assert workspace.ledger.accounts.exists?(key: "salary")
    assert_equal 18, ledger.accounts.count
    assert_includes ledger.accounts.map(&:name), "Checking Account"
  end

  test "creates a business workspace with the standard SME chart" do
    user = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")

    workspace = Workspace.create_for_user!(
      user: user,
      name: "Ife Limited",
      workspace_type: "business",
      currency_code: "NGN"
    )

    ledger = workspace.ledgers.sole
    assert workspace.ledger.accounts.exists?(key: "sales")
    assert_equal 24, ledger.accounts.count
    assert_includes ledger.accounts.map(&:name), "Bank"
    assert_includes ledger.accounts.map(&:name), "Opening Balance Equity"
  end

  test "posts the opening balance to the bank and opening balance equity through the engine" do
    user = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")

    workspace = Workspace.create_for_user!(
      user: user,
      name: "Ife's Finances",
      workspace_type: "personal",
      currency_code: "NGN",
      opening_balance_kobo: 12_500_050
    )

    entry = JournalEntry.find_by!(source_type: "OpeningBalance", source_id: workspace.id)
    ledger = workspace.ledgers.sole
    bank = ledger.accounts.find_by!(code: "1020")
    equity = ledger.accounts.find_by!(name: "Opening Balance Equity")

    assert_equal 12_500_050, entry.journal_entry_lines.find_by!(account: bank).debit
    assert_equal 12_500_050, entry.journal_entry_lines.find_by!(account: equity).credit
    assert_equal "Opening balance", entry.description
  end

  test "posts a business opening balance to the business bank account" do
    user = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")

    workspace = Workspace.create_for_user!(
      user: user,
      name: "Ife Limited",
      workspace_type: "business",
      currency_code: "NGN",
      opening_balance_kobo: 5_000_000
    )

    entry = JournalEntry.find_by!(source_type: "OpeningBalance", source_id: workspace.id)
    bank = workspace.ledgers.sole.accounts.find_by!(code: "1020")

    assert_equal 5_000_000, entry.journal_entry_lines.find_by!(account: bank).debit
  end

  test "every chart template includes the accounts the app relies on" do
    ChartCatalog::TEMPLATES.each do |type, templates|
      templates.each_key do |template|
        keys = ChartCatalog.accounts_for(type, template: template).map { |account| account[:key] }
        required = type == "business" ? %w[bank accounts_receivable accounts_payable opening_balance_equity] : %w[bank accounts_receivable opening_balance_equity]
        assert_empty required - keys, "#{type}/#{template} is missing #{required - keys}"
      end
    end
  end

  test "opening balances debit the equity account when debts exceed assets and credit contra accounts" do
    user = User.create!(full_name: "Ife Bello", email_address: "ife-obe@example.com", password: "supersecret123")

    workspace = Workspace.create_for_user!(user: user, name: "Ife Limited", workspace_type: "business", currency_code: "NGN",
      opening_balances: { "bank" => 10_000, "fixed_assets" => 50_000, "accumulated_depreciation" => 5_000, "loan_payable" => 80_000 })

    accounts = workspace.ledger.accounts.index_by(&:key)
    lines = workspace.ledger.journal_entries.sole.journal_entry_lines.to_h { |line| [ line.account_id, [ line.debit, line.credit ] ] }
    assert_equal [ 0, 5_000 ], lines[accounts["accumulated_depreciation"].id]
    assert_equal [ 25_000, 0 ], lines[accounts["opening_balance_equity"].id]
  end

  test "a rejected opening balance rolls back the whole workspace" do
    user = User.create!(full_name: "Ife Bello", email_address: "ife-rollback@example.com", password: "supersecret123")

    assert_no_difference [ "Workspace.count", "Ledger.count", "Account.count", "JournalEntry.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        Workspace.create_for_user!(user: user, name: "Ife Limited", workspace_type: "business", currency_code: "NGN",
          opening_balances: { "bank" => 10_000, "accounts_receivable" => 5_000 })
      end
    end
  end
end
