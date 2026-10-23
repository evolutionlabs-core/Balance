require "test_helper"

class Workspace::ProvisioningTest < ActiveSupport::TestCase
  test "provisions SME ledger with template and system accounts" do
    workspace = Workspace.create!(name: "SME Co", currency_code: "NGN")
    ledger = provision_business_ledger!(workspace)

    assert_equal 24, ledger.accounts.count
    assert_equal "General", ledger.name
    assert_equal "NGN", ledger.currency_code

    cash = ledger.accounts.find_by!(code: "1010")
    assert_equal "Cash", cash.name
    assert_equal "asset", cash.base_type
    assert_equal "cash", cash.subtype
    assert_equal "debit", cash.normal_balance
    assert_equal false, cash.system
    assert_equal "system", cash.created_by
    assert_equal true, cash.active

    retained = ledger.accounts.find_by!(code: "3900")
    assert_equal true, retained.system
    assert_equal "Retained Earnings", retained.name
  end

  test "picks a default income account so typed-in invoice lines can be sent" do
    personal = Workspace.create!(name: "Freelancer", currency_code: "NGN")
    personal.provision_ledger!
    business = Workspace.create!(name: "Studio", currency_code: "NGN")
    provision_business_ledger!(business)

    assert_equal "Other Income", personal.reload.default_sales_account.name
    assert_equal "Sales", business.reload.default_sales_account.name
  end

  test "provisions personal ledger with template and system accounts" do
    workspace = Workspace.create!(name: "Personal Co", currency_code: "NGN")
    ledger = workspace.provision_ledger!

    assert_equal 18, ledger.accounts.count

    salary = ledger.accounts.find_by!(code: "4010")
    assert_equal "Salary", salary.name
    assert_equal "income", salary.base_type
    assert_equal "salary", salary.subtype
  end

  test "prevents deleting a system account" do
    workspace = Workspace.create!(name: "SME Guard", currency_code: "NGN")
    ledger = provision_business_ledger!(workspace)
    account = ledger.accounts.find_by!(code: "3900")

    assert_not account.destroy
    assert Account.exists?(account.id)
  end

  test "prevents deactivating a system account" do
    workspace = Workspace.create!(name: "SME Freeze", currency_code: "NGN")
    ledger = provision_business_ledger!(workspace)
    account = ledger.accounts.find_by!(code: "3900")

    assert_not account.update(active: false)
    assert account.reload.active
  end

  test "prevents deleting an account with entries" do
    workspace = Workspace.create!(name: "SME Locked", currency_code: "NGN")
    ledger = provision_business_ledger!(workspace)
    cash = ledger.accounts.find_by!(code: "1010")
    sales = ledger.accounts.find_by!(code: "4010")
    entry = ledger.journal_entries.create!(number: 1, effective_date: Date.current)
    entry.journal_entry_lines.create!(account: cash, debit: 1000, credit: 0)
    entry.journal_entry_lines.create!(account: sales, debit: 0, credit: 1000)

    assert_not cash.destroy
    assert Account.exists?(cash.id)
  end

  test "allows deactivating an account with entries" do
    workspace = Workspace.create!(name: "SME Soft Close", currency_code: "NGN")
    ledger = provision_business_ledger!(workspace)
    cash = ledger.accounts.find_by!(code: "1010")
    sales = ledger.accounts.find_by!(code: "4010")
    entry = ledger.journal_entries.create!(number: 1, effective_date: Date.current)
    entry.journal_entry_lines.create!(account: cash, debit: 1000, credit: 0)
    entry.journal_entry_lines.create!(account: sales, debit: 0, credit: 1000)

    assert cash.update(active: false)
    assert_not cash.reload.active
  end

  test "allows deleting an account without entries" do
    workspace = Workspace.create!(name: "SME Prune", currency_code: "NGN")
    ledger = provision_business_ledger!(workspace)
    account = ledger.accounts.find_by!(code: "5900")

    assert account.destroy
    assert_not Account.exists?(account.id)
  end

  test "rejects a catalog account whose subtype does not belong to its base type" do
    workspace = Workspace.create!(name: "SME Bad Catalog", currency_code: "NGN", workspace_type: "business")
    bad = [ { key: "bad", code: "9999", name: "Bad", base_type: "asset", subtype: "salary", system: false } ]

    ChartCatalog.stub(:accounts_for, bad) do
      assert_raises(ActiveRecord::RecordInvalid) { workspace.provision_ledger! }
    end
    assert_not workspace.ledgers.exists?
  end

  test "contra accounts carry the opposite normal balance of their base type" do
    ledger = provision_business_ledger!(Workspace.create!(name: "SME Contra", currency_code: "NGN"))

    assert_equal "credit", ledger.accounts.find_by!(key: "accumulated_depreciation").normal_balance
    assert_equal "debit", ledger.accounts.find_by!(key: "owner_draws").normal_balance
  end

  test "keys the accounts the application posts to" do
    %w[personal business].each do |workspace_type|
      workspace = Workspace.create!(name: "Keys #{workspace_type}", currency_code: "NGN", workspace_type: workspace_type)
      ledger = workspace.provision_ledger!

      %w[bank accounts_receivable retained_earnings opening_balance_equity].each do |key|
        assert ledger.accounts.find_by!(key: key).system, "#{workspace_type} #{key} should be a system account"
      end
    end
  end

  test "a personal workspace keeps its personal chart names and codes" do
    ledger = Workspace.create!(name: "Personal Names", currency_code: "NGN").provision_ledger!

    assert_equal [ "1020", "Checking Account" ], ledger.accounts.find_by!(key: "bank").values_at(:code, :name)
    assert_equal [ "1050", "Accounts Receivable" ], ledger.accounts.find_by!(key: "accounts_receivable").values_at(:code, :name)
    assert_equal [ "3020", "Personal Spending" ], ledger.accounts.find_by!(key: "owner_draws").values_at(:code, :name)
  end

  test "sets the bank account as the default deposit account" do
    workspace = Workspace.create!(name: "Deposits", currency_code: "NGN")
    ledger = workspace.provision_ledger!

    assert_equal ledger.accounts.find_by!(key: "bank"), workspace.reload.default_deposit_account
  end

  test "the default deposit account must be a bank or cash account" do
    workspace = Workspace.create!(name: "Deposits", currency_code: "NGN")
    ledger = workspace.provision_ledger!

    assert_not workspace.update(default_deposit_account: ledger.accounts.find_by!(key: "credit_card"))
    assert_includes workspace.errors.full_messages, "Default deposit account must be a bank or cash account in this workspace"
  end
end
