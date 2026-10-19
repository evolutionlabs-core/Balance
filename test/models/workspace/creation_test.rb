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
end
