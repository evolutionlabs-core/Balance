module ContactsHelper
  def contact_status(contact)
    status_badge(contact.active? ? "Active" : "Inactive", tone: contact.active? ? :success : :neutral)
  end

  def contact_transaction_status(row)
    status_badge(row.status.humanize, tone: row.status == "posted" ? :success : :warning)
  end

  def contact_transaction_path(record)
    case record
    when Expense then expense_path(record)
    else raise ArgumentError, "unsupported transaction record: #{record.class}"
    end
  end
end
