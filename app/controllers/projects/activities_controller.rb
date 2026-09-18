class Projects::ActivitiesController < ApplicationController
  before_action :set_project

  def index
    @events = project_history
  end

  private
    def set_project
      @project = current_workspace.projects.includes(
        :customer,
        time_entries: :task
      ).find(params[:project_id])
    end

    def project_history
      events = []
      @project.time_entries.each do |entry|
        events << { date: entry.occurred_on, kind: "Time", record: entry }
      end
      events.sort_by { |event| event[:date].to_s }.reverse
    end
end
