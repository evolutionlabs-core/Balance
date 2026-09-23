class Projects::EstimateCalculationsController < ApplicationController
  include EstimateCalculation

  def create
    @services = current_workspace.services.ordered.to_a
    @calculation = Estimate::Calculation.new(current_workspace, Current.user, calculation_params)
  end
end
