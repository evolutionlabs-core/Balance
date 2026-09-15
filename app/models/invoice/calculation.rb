class Invoice::Calculation
  attr_reader :invoice, :lines

  def initialize(workspace, user, attributes)
    attributes = attributes.to_h
    @lines = attributes.fetch(:invoice_lines_attributes, {}).transform_values { |line| InvoiceLine.new(line) }
    @invoice = workspace.invoices.build(user: user, currency_code: attributes[:currency_code])
    @invoice.invoice_lines = lines.values
    @invoice.valid?
  end
end
