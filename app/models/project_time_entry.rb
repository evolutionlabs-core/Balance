class ProjectTimeEntry < ApplicationRecord
  belongs_to :project
  belongs_to :task, class_name: "ProjectTask", foreign_key: :project_task_id, optional: true

  validates :occurred_on, presence: true
  validates :hours, numericality: { greater_than: 0, less_than_or_equal_to: 24 }
  validates :description, presence: true
  validate :occurred_on_not_in_the_future
  validate :task_belongs_to_project

  scope :ordered, -> { order(:occurred_on, :id) }

  private
    def occurred_on_not_in_the_future
      return if occurred_on.blank?
      return if occurred_on <= Date.current

      errors.add(:occurred_on, "cannot be in the future")
    end

    def task_belongs_to_project
      return if task.blank? || project.blank?
      return if task.project_id == project_id

      errors.add(:task, "must belong to the same project")
    end
end
