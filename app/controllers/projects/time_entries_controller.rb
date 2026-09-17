class Projects::TimeEntriesController < ApplicationController
  before_action :set_project
  before_action :set_time_entry, only: %i[edit update destroy]

  def index
    @time_entries = @project.time_entries.ordered.includes(:task)
  end

  def new
    @time_entry = @project.time_entries.build(
      occurred_on: Date.current, project_task_id: preselected_task_id
    )
  end

  def create
    @time_entry = @project.time_entries.build(time_entry_params)

    if @time_entry.save
      redirect_out_of_frame project_project_time_entries_path(@project), notice: "Time logged."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @time_entry.update(time_entry_params)
      redirect_out_of_frame project_project_time_entries_path(@project), notice: "Time entry saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @time_entry.destroy!
    redirect_to project_project_time_entries_path(@project), notice: "Time entry removed."
  end

  private
    def set_project
      @project = current_workspace.projects.find(params[:project_id])
    end

    def set_time_entry
      @time_entry = @project.time_entries.find(params[:id])
    end

    def preselected_task_id
      task_id = params[:task_id]
      if task_id.present? && @project.tasks.exists?(task_id)
        task_id
      end
    end

    def time_entry_params
      params.expect(project_time_entry: [
        :project_task_id, :occurred_on, :hours, :description, :internal_note
      ])
    end
end
