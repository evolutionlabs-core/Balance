module InvoicesHelper
  def invoice_status_badge(invoice)
    status_badge(invoice_status_label(invoice), tone: invoice.overdue? ? :danger : :neutral)
  end

  def invoice_status_label(invoice)
    if invoice.draft?
      "Draft"
    elsif invoice.voided?
      "Voided"
    elsif invoice.paid? || invoice.balance_due_kobo.zero?
      "Paid"
    elsif invoice.overdue?
      "Overdue #{pluralize(invoice.days_overdue, "day")}"
    elsif invoice.balance_due_kobo < invoice.total_minor
      "Partially paid"
    elsif invoice.due_date.nil?
      "Sent"
    elsif invoice.due_date == Date.current
      "Due today"
    else
      "Due in #{pluralize((invoice.due_date - Date.current).to_i, "day")}"
    end
  end

  def invoice_row_action(invoice, **options)
    if invoice.draft?
      link_to "Send", invoice_path(invoice, view: "email"), **options
    elsif invoice.sent? && invoice.balance_due_kobo.positive?
      link_to "Receive payment", new_invoice_payment_path(invoice), data: { turbo_frame: "modal" }, **options
    else
      link_to "View", invoice_path(invoice), **options
    end
  end
end
