class LedgerLine < ApplicationRecord
  belongs_to :ledger_entry
  belongs_to :ledger_account
end
