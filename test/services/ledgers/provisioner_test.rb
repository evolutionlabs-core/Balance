require "test_helper"

class Ledgers::ProvisionerTest < ActiveSupport::TestCase
  test "provisions SME ledger with template and system accounts" do
    workspace = Workspace.create!(name: "SME Co", currency_code: "NGN")
    ledger = Ledgers::Provisioner.call(workspace: workspace, template: "standard_sme")

    assert_equal 24, ledger.ledger_accounts.count
    assert_equal "General", ledger.name
    assert_equal "NGN", ledger.currency_code

    cash = ledger.ledger_accounts.find_by!(code: "1010")
    assert_equal "Cash", cash.name
    assert_equal "asset", cash.base_type
    assert_equal "cash", cash.subtype
    assert_equal "debit", cash.normal_balance
    assert_equal false, cash.system
    assert_equal "system", cash.created_by
    assert_equal true, cash.active

    retained = ledger.ledger_accounts.find_by!(code: "3900")
    assert_equal true, retained.system
    assert_equal "Retained Earnings", retained.name
  end

  test "provisions personal ledger with template and system accounts" do
    workspace = Workspace.create!(name: "Personal Co", currency_code: "NGN")
    ledger = Ledgers::Provisioner.call(workspace: workspace, template: "personal_finance")

    assert_equal 17, ledger.ledger_accounts.count

    salary = ledger.ledger_accounts.find_by!(code: "4010")
    assert_equal "Salary", salary.name
    assert_equal "income", salary.base_type
    assert_equal "salary", salary.subtype
  end

  test "prevents deleting a system account" do
    workspace = Workspace.create!(name: "SME Guard", currency_code: "NGN")
    ledger = Ledgers::Provisioner.call(workspace: workspace, template: "standard_sme")
    account = ledger.ledger_accounts.find_by!(code: "3900")

    assert_not account.destroy
    assert LedgerAccount.exists?(account.id)
  end

  test "prevents deactivating a system account" do
    workspace = Workspace.create!(name: "SME Freeze", currency_code: "NGN")
    ledger = Ledgers::Provisioner.call(workspace: workspace, template: "standard_sme")
    account = ledger.ledger_accounts.find_by!(code: "3900")

    assert_not account.update(active: false)
    assert account.reload.active
  end

  test "prevents deleting an account with entries" do
    workspace = Workspace.create!(name: "SME Locked", currency_code: "NGN")
    ledger = Ledgers::Provisioner.call(workspace: workspace, template: "standard_sme")
    cash = ledger.ledger_accounts.find_by!(code: "1010")
    sales = ledger.ledger_accounts.find_by!(code: "4010")
    entry = ledger.ledger_entries.create!(effective_date: Date.current)
    entry.ledger_lines.create!(ledger_account: cash, debit: 1000, credit: 0)
    entry.ledger_lines.create!(ledger_account: sales, debit: 0, credit: 1000)

    assert_not cash.destroy
    assert LedgerAccount.exists?(cash.id)
  end

  test "allows deactivating an account with entries" do
    workspace = Workspace.create!(name: "SME Soft Close", currency_code: "NGN")
    ledger = Ledgers::Provisioner.call(workspace: workspace, template: "standard_sme")
    cash = ledger.ledger_accounts.find_by!(code: "1010")
    sales = ledger.ledger_accounts.find_by!(code: "4010")
    entry = ledger.ledger_entries.create!(effective_date: Date.current)
    entry.ledger_lines.create!(ledger_account: cash, debit: 1000, credit: 0)
    entry.ledger_lines.create!(ledger_account: sales, debit: 0, credit: 1000)

    assert cash.update(active: false)
    assert_not cash.reload.active
  end

  test "allows deleting an account without entries" do
    workspace = Workspace.create!(name: "SME Prune", currency_code: "NGN")
    ledger = Ledgers::Provisioner.call(workspace: workspace, template: "standard_sme")
    account = ledger.ledger_accounts.find_by!(code: "5900")

    assert account.destroy
    assert_not LedgerAccount.exists?(account.id)
  end

  test "raises for template row with invalid subtype" do
    workspace = Workspace.create!(name: "SME Bad Template", currency_code: "NGN")
    bad = { "accounts" => [ { "code" => "9999", "name" => "Bad", "base_type" => "asset", "subtype" => "bogus", "normal_balance" => "debit" } ] }

    Bootsnap::CompileCache::YAML.stub(:supported_internal_encoding?, false) do
      YAML.stub(:load_file, bad) do
        assert_raises(ArgumentError) do
          Ledgers::Provisioner.call(workspace: workspace, template: "standard_sme")
        end
      end
    end
  end
end
