class CreditNote::Calculation
  attr_reader :credit_note

  def initialize(workspace, user, attributes)
    attributes = attributes.to_h
    @credit_note = workspace.credit_notes.build(user: user, currency_code: workspace.currency_code,
      invoice: workspace.invoices.find_by(id: attributes.delete("invoice_id")))
    @credit_note.assign_attributes(attributes)
    @credit_note.valid?
  end
end
