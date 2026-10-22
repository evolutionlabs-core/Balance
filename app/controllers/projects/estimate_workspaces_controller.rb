class Projects::EstimateWorkspacesController < ApplicationController
  before_action :set_project
  before_action :set_estimate

  def edit
    @workspace = current_workspace
  end

  def update
    @workspace = current_workspace

    if @workspace.update(workspace_params)
      if @estimate.persisted?
        @estimate.refresh_business_details
      else
        @estimate.populate_party_details
      end
      render :refresh
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_project
      @project = current_workspace.projects.find(params[:project_id])
    end

    def set_estimate
      @estimate = if params[:estimate_id].present?
        current_workspace.estimates.find(params[:estimate_id])
      else
        @project.estimates.build(user: Current.user, customer: @project.customer, currency_code: @project.currency_code)
      end
    end

    def workspace_params
      params.expect(workspace: [ :name, :address, :default_sales_account_id ])
    end
end
