class Customer < ApplicationRecord
  CUSTOMER_TYPES = %w[single business].freeze

  belongs_to :workspace
  has_many :invoices, dependent: :restrict_with_error

  validates :name, :email, :customer_type, presence: true
  validates :customer_type, inclusion: { in: CUSTOMER_TYPES }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
end
