class JournalEntry < ApplicationRecord
  REVERSIBLE_SOURCES = [ nil, "Entry", "JournalEntryDraft", "OpeningBalance" ].freeze

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

  def reversible?
    REVERSIBLE_SOURCES.include?(source_type) && !reverses_entry_id? && !reversed?
  end

  def templatable?
    REVERSIBLE_SOURCES.include?(source_type) && !reverses_entry_id? && source_type != "OpeningBalance"
  end

  def total
    journal_entry_lines.sum(&:debit)
  end

  def source_document
    workspace = ledger.workspace

    case source_type
    when "Invoice" then workspace.invoices.find_by(id: source_id)
    when "InvoicePayment" then workspace.invoice_payments.find_by(id: source_id)&.invoice
    when "CreditNote" then workspace.credit_notes.find_by(id: source_id)
    when "Bill" then workspace.bills.find_by(id: source_id)
    when "BillPayment" then workspace.bill_payments.find_by(id: source_id)&.bill
    when "Expense" then workspace.expenses.find_by(id: source_id)
    end
  end
end
