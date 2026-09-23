class Projects::InvoicesController < ApplicationController
  before_action :set_project

  def index
    @invoices = @project.invoices.includes(:customer, :receivable_applications).order(created_at: :desc)
  end

  private
    def set_project
      @project = current_workspace.projects.includes(:customer).find(params[:project_id])
    end
end
