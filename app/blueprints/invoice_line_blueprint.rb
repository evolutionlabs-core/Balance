class InvoiceLineBlueprint < Blueprinter::Base
  identifier :id

  fields :description, :quantity, :rate_minor, :amount_minor, :position
end
