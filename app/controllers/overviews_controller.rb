class OverviewsController < ApplicationController
  def show
    @summary = LedgerSummary.new(current_workspace)
    @days = params.fetch(:days, 30).to_i.clamp(7, 90)
    @balance_sheet = ledger && Engine::Query.call(ledger_id: ledger.id, query_type: "balance_sheet")[:data]
  end

  private
    def ledger
      @ledger ||= current_workspace.ledgers.first
    end
end
