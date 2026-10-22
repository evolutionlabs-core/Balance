class ReportsController < ApplicationController
  def balance_sheet
    @as_of = [ parse_date(params[:as_of]) || Date.current, Date.current ].min
    @comparison, dates = ReportPeriod.balance_sheet(@as_of, params[:compare], year_start_month: year_start_month)
    @statement = AccountingEngine::FinancialStatements.balance_sheet(ledger: ledger, dates: dates) if ledger

    respond_with_csv("balance-sheet") { ReportCsv.statement(@statement) if @statement }
  end

  def income_statement
    @period, periods = ReportPeriod.income_statement(params[:period], year_start_month: year_start_month)
    @statement = AccountingEngine::FinancialStatements.income_statement(ledger: ledger, periods: periods) if ledger

    respond_with_csv("income-statement") { ReportCsv.statement(@statement) if @statement }
  end

  def cash_flow
    @period, periods = ReportPeriod.income_statement(params[:period], year_start_month: year_start_month)
    @statement = AccountingEngine::FinancialStatements.cash_flow(ledger: ledger, periods: periods) if ledger

    respond_with_csv("cash-flow") { ReportCsv.statement(@statement) if @statement }
  end

  def trial_balance
    @trial_balance = AccountingEngine::TrialBalance.new(ledger) if ledger

    respond_with_csv("trial-balance") { ReportCsv.trial_balance(@trial_balance) if @trial_balance }
  end

  def general_ledger
    @trial_balance = AccountingEngine::TrialBalance.new(ledger) if ledger
  end

  def general_ledger_account
    account = current_workspace.accounts.find(params[:account_id])
    to = [ parse_date(params[:to]) || Date.current, Date.current ].min
    from = [ parse_date(params[:from]) || FinancialYear.start_for(to, year_start_month), to ].min
    @general_ledger = AccountingEngine::GeneralLedger.new(account, from: from, to: to)

    respond_with_csv("general-ledger-#{account.code}") { ReportCsv.general_ledger(@general_ledger) }
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
    def year_start_month
      current_workspace.fiscal_year_start_month
    end

    def respond_with_csv(name)
      respond_to do |format|
        format.html
        format.csv do
          if (csv = yield)
            send_data csv, filename: "#{name}-#{Date.current.iso8601}.csv", type: "text/csv"
          else
            head :not_found
          end
        end
      end
    end

    def ledger
      @ledger ||= current_workspace.ledgers.first
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error, TypeError
      nil
    end
end
