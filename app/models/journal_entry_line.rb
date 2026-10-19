class JournalEntryLine < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :account

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }
end
