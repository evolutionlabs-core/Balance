class Projects::BudgetsController < ApplicationController
  before_action :set_project

  def edit
  end

  def update
    if @project.update(budget_params)
      redirect_out_of_frame project_path(@project), notice: "Project budget saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_project
      @project = current_workspace.projects.find(params[:project_id])
    end

    def budget_params
      params.expect(project: [ :cost_budget ])
    end
end
