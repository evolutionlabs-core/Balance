class JournalEntryLine < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :account
  belongs_to :customer, optional: true
  belongs_to :vendor, optional: true

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }
end
