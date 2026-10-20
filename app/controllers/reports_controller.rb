class ReportsController < ApplicationController
  def balance_sheet
    @as_of = [ parse_date(params[:as_of]) || Date.current, Date.current ].min
    @comparison, dates = ReportPeriod.balance_sheet(@as_of, params[:compare])
    return unless ledger

    @statement = AccountingEngine::FinancialStatements.balance_sheet(ledger: ledger, dates: dates)
  end

  def income_statement
    @period, periods = ReportPeriod.income_statement(params[:period])
    return unless ledger

    @statement = AccountingEngine::FinancialStatements.income_statement(ledger: ledger, periods: periods)
  end

  def trial_balance
    @trial_balance = AccountingEngine::TrialBalance.new(ledger) if ledger
  end

  def general_ledger
    @trial_balance = AccountingEngine::TrialBalance.new(ledger) if ledger
  end

  def general_ledger_account
    account = current_workspace.accounts.find(params[:account_id])
    @general_ledger = AccountingEngine::GeneralLedger.new(account, from: Date.current.beginning_of_year)
  end

  def aged_receivables
    @aging = AgedBalances.new(current_workspace, side: :receivables) if ledger
  end

  def aged_payables
    if current_workspace.business?
      @aging = AgedBalances.new(current_workspace, side: :payables) if ledger
    else
      redirect_to aged_receivables_path, alert: "Payables are only available in business workspaces."
    end
  end

  private
    def ledger
      @ledger ||= current_workspace.ledgers.first
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error, TypeError
      nil
    end
end
