class Ledger < ApplicationRecord
  include Ledgers::Books

  belongs_to :workspace
  belongs_to :closed_by, class_name: "User", optional: true
  has_many :accounts, dependent: :restrict_with_error
  has_many :journal_entries, dependent: :restrict_with_error

  validates :workspace_id, uniqueness: true
  validates :closed_at, presence: true, if: -> { closed_through.present? }
  validates :closed_by, presence: true, if: -> { closed_through.present? }

  def active?
    status == "active"
  end

  def closed_through?(date)
    closed_through.present? && date <= closed_through
  end
end
