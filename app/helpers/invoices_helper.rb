module InvoicesHelper
  def invoice_status_badge(invoice)
    balance_due_kobo = invoice.balance_due_kobo

    if invoice.posted? && balance_due_kobo.zero?
      status_badge("Paid", tone: :success)
    elsif invoice.posted? && balance_due_kobo < invoice.total_minor
      status_badge("Partially paid", tone: :warning)
    elsif invoice.posted?
      status_badge("Posted", tone: :success)
    else
      status_badge("Draft", tone: :warning)
    end
  end
end
