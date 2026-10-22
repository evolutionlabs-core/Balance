class OverviewsController < ApplicationController
  def show
    @overview = Overview.for(current_workspace, days: params.fetch(:days, 30).to_i)
  end
end
