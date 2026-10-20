require "test_helper"

class OverviewTest < ActiveSupport::TestCase
  test "picks the overview for the workspace type" do
    assert_instance_of Overview::Personal, Overview.for(workspaces(:ada_store), days: 30)
    assert_instance_of Overview::Business, Overview.for(workspaces(:chidi_supplies), days: 30)
  end

  test "keeps the period within the offered range" do
    assert_equal 7, Overview.for(workspaces(:ada_store), days: 1).days
    assert_equal 365, Overview.for(workspaces(:ada_store), days: 9_999).days
  end

  test "reads copy from the workspace type and falls back to shared wording" do
    personal = Overview.for(workspaces(:ada_store), days: 30)
    business = Overview.for(workspaces(:chidi_supplies), days: 30)

    assert_equal "Money in", personal.t("kpis.income")
    assert_equal "Revenue", business.t("kpis.income")
    assert_equal "Expenses", business.t("kpis.expenses")
    assert_equal "Cash flow", business.t("cash_flow.title")
  end

  test "every workspace type has an overview with copy for each of its panels and figures" do
    Workspace.workspace_types.each_key do |type|
      overview = Overview.for(Workspace.new(workspace_type: type, currency_code: "NGN"), days: 30)

      assert overview.rows.flatten.all? { |panel| I18n.exists?("overviews.shared.#{panel}") || I18n.exists?("overviews.#{type}.#{panel}") }, "#{type} is missing panel copy"
      overview.kpis.each { |kpi| assert_not_includes overview.t("kpis.#{kpi.key}"), "Translation missing" }
    end
  end

  test "personal net worth moves with the balance sheet across the period" do
    workspace = workspaces(:ada_store)
    ledger = workspace.provision_ledger!
    cash = ledger.accounts.find_by!(name: "Cash")
    salary = ledger.accounts.find_by!(name: "Salary")
    post_journal_entry!(workspace, debit_account: cash, credit_account: salary, amount_kobo: 1_000_00, effective_date: 60.days.ago.to_date)
    post_journal_entry!(workspace, debit_account: cash, credit_account: salary, amount_kobo: 250_00)

    net_worth = Overview.for(workspace, days: 30).kpis.find { |kpi| kpi.key == :net_worth }

    assert_equal 1_250_00, net_worth.amount_kobo
    assert_equal 250_00, net_worth.change_kobo
  end

  test "folds expenses beyond the largest few into one slice" do
    workspace = workspaces(:chidi_supplies)
    ledger = workspace.provision_ledger!
    bank = ledger.accounts.find_by!(key: "bank")
    %w[rent payroll marketing professional_fees utilities other_expense cost_of_goods_sold].each_with_index do |key, index|
      post_journal_entry!(workspace, debit_account: ledger.accounts.find_by!(key: key), credit_account: bank, amount_kobo: (index + 1) * 100_00)
    end

    slices = Overview.for(workspace, days: 30).top_expenses

    assert_equal Overview::TOP_EXPENSES + 1, slices.size
    assert_equal "Everything else", slices.last.label
    assert_equal 300_00, slices.last.amount_kobo
    assert_equal 28_00_00, slices.sum(&:amount_kobo)
  end

  test "reads a change as a percentage of where the figure started" do
    assert_in_delta 25.0, Overview::Kpi.new(key: :income, amount_kobo: 500_00, change_kobo: 100_00, compared_to: :previous_period, rising_is_good: true).change_percent
    assert_nil Overview::Kpi.new(key: :net_loss, amount_kobo: -1_010_500_00, change_kobo: -1_340_500_00, compared_to: :previous_period, rising_is_good: true).change_percent, "profit turning to loss"
    assert_nil Overview::Kpi.new(key: :net_loss, amount_kobo: -300_00, change_kobo: -200_00, compared_to: :previous_period, rising_is_good: true).change_percent, "a loss deepening"
    assert_nil Overview::Kpi.new(key: :cash, amount_kobo: 500_00, change_kobo: 500_00, compared_to: :period_start, rising_is_good: true).change_percent
  end
end
