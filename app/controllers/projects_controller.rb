class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show edit update]

  def index
    @projects = current_workspace.projects.includes(:customer).ordered
  end

  def new
    @project = current_workspace.projects.build(currency_code: current_workspace.currency_code)
  end

  def create
    @project = current_workspace.projects.build(project_params)

    if @project.save
      redirect_out_of_frame project_path(@project), notice: "Project created. Add estimates to get started."
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @summary = Projects::Summary.new(@project)
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_out_of_frame project_path(@project), notice: "Project saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_project
      @project = current_workspace.projects.includes(:customer).find(params[:id])
    end

    def project_params
      params.expect(project: [
        :customer_id, :name, :description, :currency_code
      ])
    end
end
