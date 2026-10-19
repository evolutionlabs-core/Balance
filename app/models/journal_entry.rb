class JournalEntry < ApplicationRecord
  belongs_to :ledger
  belongs_to :posted_by, class_name: "User", optional: true
  belongs_to :reverses_entry, class_name: "JournalEntry", optional: true
  has_one :reversal, class_name: "JournalEntry", foreign_key: :reverses_entry_id, inverse_of: :reverses_entry
  has_many :journal_entry_lines, dependent: :restrict_with_error

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }

  def reversed?
    reversal.present?
  end
end
