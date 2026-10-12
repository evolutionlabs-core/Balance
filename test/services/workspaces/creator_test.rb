require "test_helper"

class Workspaces::CreatorTest < ActiveSupport::TestCase
  test "creates a personal workspace with the personal finance chart and no legacy accounts" do
    user = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")

    workspace = Workspaces::Creator.call(
      user: user,
      name: "Ife's Finances",
      workspace_type: "personal",
      currency_code: "NGN"
    )

    assert_equal user, workspace.memberships.owner.first.user
    assert_empty workspace.accounts

    ledger = workspace.ledgers.sole
    assert_equal "personal_finance", workspace.ledger_template
    assert_equal 17, ledger.ledger_accounts.count
    assert_includes ledger.ledger_accounts.map(&:name), "Checking Account"
  end

  test "creates a business workspace with the standard SME chart" do
    user = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")

    workspace = Workspaces::Creator.call(
      user: user,
      name: "Ife Limited",
      workspace_type: "business",
      currency_code: "NGN"
    )

    ledger = workspace.ledgers.sole
    assert_equal "standard_sme", workspace.ledger_template
    assert_equal 24, ledger.ledger_accounts.count
    assert_includes ledger.ledger_accounts.map(&:name), "Bank"
    assert_includes ledger.ledger_accounts.map(&:name), "Opening Balance Equity"
  end

  test "posts the opening balance to the bank and opening balance equity through the engine" do
    user = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")

    workspace = Workspaces::Creator.call(
      user: user,
      name: "Ife's Finances",
      workspace_type: "personal",
      currency_code: "NGN",
      opening_balance_kobo: 12_500_050
    )

    entry = LedgerEntry.find_by!(source_type: "OpeningBalance", source_id: workspace.id)
    ledger = workspace.ledgers.sole
    bank = ledger.ledger_accounts.find_by!(code: "1020")
    equity = ledger.ledger_accounts.find_by!(name: "Opening Balance Equity")

    assert_equal 12_500_050, entry.ledger_lines.find_by!(ledger_account: bank).debit
    assert_equal 12_500_050, entry.ledger_lines.find_by!(ledger_account: equity).credit
  end

  test "posts a business opening balance to the business bank account" do
    user = User.create!(full_name: "Ife Bello", email_address: "ife@example.com", password: "supersecret123")

    workspace = Workspaces::Creator.call(
      user: user,
      name: "Ife Limited",
      workspace_type: "business",
      currency_code: "NGN",
      opening_balance_kobo: 5_000_000
    )

    entry = LedgerEntry.find_by!(source_type: "OpeningBalance", source_id: workspace.id)
    bank = workspace.ledgers.sole.ledger_accounts.find_by!(code: "1020")

    assert_equal 5_000_000, entry.ledger_lines.find_by!(ledger_account: bank).debit
  end
end
