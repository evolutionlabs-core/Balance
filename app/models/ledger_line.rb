class LedgerLine < ApplicationRecord
  belongs_to :ledger_entry
  belongs_to :ledger_account

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }
end
