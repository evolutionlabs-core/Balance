class InvoiceSummary
  Total = Data.define(:count, :amount_kobo)

  PAID_WINDOW_DAYS = 30

  def initialize(workspace, on: Date.current)
    @workspace = workspace
    @on = on
  end

  def overdue
    total(outstanding.select { |invoice| invoice.overdue?(@on) })
  end

  def not_due
    total(outstanding.reject { |invoice| invoice.overdue?(@on) })
  end

  def paid_recently_kobo
    @workspace.invoice_payments
      .left_joins(:journal_entry)
      .where("COALESCE(journal_entries.effective_date, invoice_payments.created_at::date) BETWEEN ? AND ?", @on - (PAID_WINDOW_DAYS - 1), @on)
      .sum(Arel.sql("CASE WHEN invoice_payments.reverses_invoice_payment_id IS NULL THEN invoice_payments.amount_kobo ELSE -invoice_payments.amount_kobo END"))
  end

  private
    def outstanding
      @outstanding ||= @workspace.invoices.outstanding.includes(:payments).to_a.select { |invoice| invoice.balance_due_kobo.positive? }
    end

    def total(invoices)
      Total.new(count: invoices.size, amount_kobo: invoices.sum(&:balance_due_kobo))
    end
end
