class Ledger < ApplicationRecord
  belongs_to :workspace
  has_many :ledger_accounts, dependent: :restrict_with_error
  has_many :ledger_entries, dependent: :restrict_with_error

  validates :workspace_id, uniqueness: true

  def active?
    status == "active"
  end
end
