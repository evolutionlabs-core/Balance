class ProjectTask < ApplicationRecord
  STATUSES = %w[todo doing done].freeze

  belongs_to :project
  has_many :time_entries, class_name: "ProjectTimeEntry", foreign_key: :project_task_id, dependent: :nullify

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :ordered, -> { order(:position, :id) }
end
