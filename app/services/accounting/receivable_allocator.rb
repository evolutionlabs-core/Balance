class Accounting::ReceivableAllocator
  # Retired with the invoice engine cutover: customer receipts allocate through
  # Invoices::PaymentRecorder onto ledger entries, and legacy journal receipts
  # no longer carry applications.
  def self.call(_journal_entry, preferred_invoice: nil)
    nil
  end
end
