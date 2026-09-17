class Projects::EstimateCalculationsController < ApplicationController
  include EstimateCalculation

  def create
    @calculation = Estimate::Calculation.new(current_workspace, Current.user, calculation_params)
  end
end
