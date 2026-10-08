class LedgerEntry < ApplicationRecord
  belongs_to :ledger
  has_many :ledger_lines, dependent: :restrict_with_error
end
