module CreditNotesHelper
  def credit_note_status_badge(credit_note)
    status_badge(credit_note_status_label(credit_note), tone: :neutral)
  end

  def credit_note_status_label(credit_note)
    if credit_note.voided?
      "Voided"
    elsif credit_note.unapplied_minor.zero?
      "Applied"
    elsif credit_note.applied_minor.positive?
      "Partly applied"
    else
      "Available"
    end
  end
end
