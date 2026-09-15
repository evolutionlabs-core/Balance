class OverviewsController < ApplicationController
  def show
    @summary = LedgerSummary.new(current_workspace)
    @days = params.fetch(:days, 30).to_i.clamp(7, 90)
  end
end
