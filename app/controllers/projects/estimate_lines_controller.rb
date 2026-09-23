class Projects::EstimateLinesController < ApplicationController
  include EstimateCalculation

  def new
    @project = current_workspace.projects.find(params[:project_id])
    @index = SecureRandom.random_number(10**18)
    @line = EstimateLineItem.new
  end

  def destroy
    attributes = calculation_params
    attributes[:line_items_attributes].delete(params[:id])
    @calculation = Estimate::Calculation.new(current_workspace, Current.user, attributes)
  end
end
