module ContactsHelper
  def contact_status(contact)
    status_pill(contact.active? ? "Active" : "Inactive", tone: contact.active? ? :positive : :neutral)
  end

  def contact_transaction_status(row)
    status_pill(row.status.humanize, tone: row.status == "posted" ? :positive : :pending)
  end

  def contact_transaction_path(record)
    case record
    when Expense then expense_path(record)
    else raise ArgumentError, "unsupported transaction record: #{record.class}"
    end
  end
end
