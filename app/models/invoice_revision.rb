class InvoiceRevision < ApplicationRecord
  belongs_to :workspace
  belongs_to :invoice
  belongs_to :user

  validates :field_changes, presence: true

  before_update { throw(:abort) }
  before_destroy { throw(:abort) }
end
