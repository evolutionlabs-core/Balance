class Projects::ActionsController < ApplicationController
  before_action :set_estimate

  private
    def set_estimate
      @estimate = current_workspace.estimates.find(params[:estimate_id])
      @project = @estimate.project
    end

    def respond_with_transition(notice:, alert:)
      yield
      redirect_to project_estimate_path(@estimate), notice: notice
    rescue AASM::InvalidTransition
      redirect_to project_estimate_path(@estimate), alert: alert
    end
end
