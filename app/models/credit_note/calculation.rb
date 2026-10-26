class CreditNote::Calculation
  attr_reader :credit_note

  def initialize(workspace, user, attributes)
    @credit_note = workspace.credit_notes.build(user: user, currency_code: workspace.currency_code)
    @credit_note.assign_attributes(attributes.to_h)
    @credit_note.valid?
  end
end
