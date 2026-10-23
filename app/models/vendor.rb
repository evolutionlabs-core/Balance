class Vendor < ApplicationRecord
  belongs_to :workspace
  has_many :bills, dependent: :restrict_with_error
  has_many :bill_payments, through: :bills, source: :payments

  validates :name, presence: true
  validates :email, email: true
  validates :phone, phone: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
end
