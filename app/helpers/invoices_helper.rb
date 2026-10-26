module InvoicesHelper
  REVISION_LABELS = {
    "payment_terms" => "Terms",
    "due_date" => "Due date",
    "reference" => "Reference",
    "bill_to_email" => "Billing email",
    "notes" => "Note to customer",
    "internal_note" => "Internal note"
  }.freeze

  def invoice_status_badge(invoice)
    status_badge(invoice_status_label(invoice), tone: invoice.overdue? ? :danger : :neutral)
  end

  def invoice_status_label(invoice)
    if invoice.draft?
      "Draft"
    elsif invoice.voided?
      "Voided"
    elsif (invoice.paid? || invoice.balance_due_kobo.zero?) && invoice.applied_amount_kobo.zero? && invoice.credited_amount_minor.positive?
      "Credited"
    elsif invoice.paid? || invoice.balance_due_kobo.zero?
      "Paid"
    elsif invoice.overdue?
      "Overdue #{pluralize(invoice.days_overdue, "day")}"
    elsif invoice.applied_amount_kobo.positive?
      "Partially paid"
    elsif invoice.due_date.nil?
      "Sent"
    elsif invoice.due_date == Date.current
      "Due today"
    else
      "Due in #{pluralize((invoice.due_date - Date.current).to_i, "day")}"
    end
  end

  def invoice_revision_changes(revision)
    revision.field_changes.map do |field, (from, to)|
      [ REVISION_LABELS.fetch(field), invoice_revision_value(field, from), invoice_revision_value(field, to) ]
    end
  end

  def invoice_revision_value(field, value)
    if value.blank?
      "—"
    elsif field == "payment_terms"
      PaymentTerms.label(value)
    elsif field == "due_date"
      Date.iso8601(value).strftime("%b %-d, %Y")
    else
      truncate(value, length: 80)
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
