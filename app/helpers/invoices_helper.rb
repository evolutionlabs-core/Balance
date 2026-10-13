module InvoicesHelper
  def invoice_status_badge(invoice)
    if invoice.paid?
      status_badge("Paid", tone: :success)
    elsif invoice.sent? && invoice.balance_due_kobo.zero?
      status_badge("Paid", tone: :success)
    elsif invoice.sent? && invoice.balance_due_kobo < invoice.total_minor
      status_badge("Partially paid", tone: :warning)
    elsif invoice.sent?
      status_badge("Sent", tone: :success)
    elsif invoice.voided?
      status_badge("Voided", tone: :warning)
    else
      status_badge("Draft", tone: :warning)
    end
  end
end
