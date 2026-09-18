class Projects::TasksController < ApplicationController
  before_action :set_project
  before_action :set_task, only: %i[edit update destroy]

  def index
    @tasks = @project.tasks.ordered
    @time_entries = @project.time_entries.ordered.includes(:task).limit(5)
  end

  def new
    @task = @project.tasks.build(task_defaults)
  end

  def create
    @task = @project.tasks.build(task_params)

    if @task.save
      redirect_out_of_frame project_project_tasks_path(@project), notice: "Task added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @task.update(task_params)
      redirect_out_of_frame project_project_tasks_path(@project), notice: "Task saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @task.destroy!
    redirect_to project_project_tasks_path(@project), notice: "Task removed."
  end

  private
    def set_project
      @project = current_workspace.projects.find(params[:project_id])
    end

    def set_task
      @task = @project.tasks.find(params[:id])
    end

    def task_defaults
      { status: "todo", position: @project.tasks.size }
    end

    def task_params
      params.expect(project_task: [
        :title, :description, :status, :position, :internal_note
      ])
    end
end
