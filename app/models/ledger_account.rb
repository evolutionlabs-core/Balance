class LedgerAccount < ApplicationRecord
  belongs_to :ledger
  has_many :ledger_lines, dependent: :restrict_with_error

  scope :ordered, -> { order(:name) }

  before_destroy { throw(:abort) if system? }
  before_update { throw(:abort) if system? && !active && active_was }
end
