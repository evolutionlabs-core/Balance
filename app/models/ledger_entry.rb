class LedgerEntry < ApplicationRecord
  belongs_to :ledger
  belongs_to :reverses_ledger_entry, class_name: "LedgerEntry", optional: true
  has_many :ledger_lines, dependent: :restrict_with_error
  has_many :reversals, class_name: "LedgerEntry", foreign_key: :reverses_ledger_entry_id, dependent: :restrict_with_error

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }
end
