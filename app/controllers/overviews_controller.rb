class OverviewsController < ApplicationController
  def show
    @summary = LedgerSummary.new(current_workspace)
    @days = params.fetch(:days, 30).to_i.clamp(7, 90)
    return unless ledger

    @position = AccountingEngine::Query.call(ledger_id: ledger.id, query_type: "balance_sheet")[:data]
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
