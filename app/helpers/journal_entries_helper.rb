module JournalEntriesHelper
  def journal_entry_source(entry)
    document = entry.source_document

    if document
      link_to journal_entry_document_label(document), document, class: "font-medium text-balance-teal-700 hover:underline"
    else
      journal_entry_origin_label(entry)
    end
  end

  def journal_entry_document_label(document)
    case document
    when Invoice then "Invoice #{document.invoice_number}"
    when Bill then document.display_name
    when Expense then "Expense"
    end
  end

  def journal_entry_origin_label(entry)
    case entry.source_type
    when "Entry" then entry.source_id ? "Assistant" : "Manual"
    when nil, "JournalEntry", "JournalEntryDraft" then "Manual"
    else entry.source_type.underscore.humanize
    end
  end

  def journal_entry_status(entry)
    if (label = journal_entry_status_label(entry))
      status_badge(label, tone: entry.reversed? ? :warning : :neutral)
    end
  end

  def journal_entry_status_label(entry)
    if entry.reversed?
      "Reversed"
    elsif entry.reverses_entry_id?
      "Reversal"
    end
  end
end
