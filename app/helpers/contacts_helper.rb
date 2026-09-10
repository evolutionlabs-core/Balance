module ContactsHelper
  def contact_status(contact)
    classes = contact.active? ? "bg-emerald-50 text-emerald-700" : "bg-neutral-100 text-neutral-500"
    tag.span(contact.active? ? "Active" : "Inactive", class: "inline-flex rounded-full px-2 py-1 text-xs font-medium #{classes}")
  end

  def contact_transaction_status(row)
    classes = row.status == "posted" ? "bg-emerald-50 text-emerald-700" : "bg-amber-50 text-amber-700"
    tag.span(row.status.humanize, class: "inline-flex rounded-full px-2 py-1 text-xs font-medium #{classes}")
  end

  def contact_transaction_path(record)
    case record
    when Expense then expense_path(record)
    else raise ArgumentError, "unsupported transaction record: #{record.class}"
    end
  end
end
