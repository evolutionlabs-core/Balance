class OverviewsController < ApplicationController
  def show
    @summary = LedgerSummary.new(current_workspace)
    @days = params.fetch(:days, 30).to_i.clamp(7, 90)
    return unless ledger

    @position = AccountingEngine::FinancialStatements.balance_sheet(ledger: ledger, dates: [ [ Date.current.strftime("%b %-d, %Y"), Date.current ] ])
    if current_workspace.business?
      @receivables = AgedBalances.new(current_workspace, side: :receivables)
      @payables = AgedBalances.new(current_workspace, side: :payables)
    end
  end

  private
    def ledger
      @ledger ||= current_workspace.ledgers.first
    end
end
