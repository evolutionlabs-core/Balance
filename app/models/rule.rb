class Rule < ApplicationRecord
  belongs_to :ledger, optional: true

  validates :name, :severity, :message, presence: true
  validates :severity, inclusion: { in: %w[block warn] }
end
