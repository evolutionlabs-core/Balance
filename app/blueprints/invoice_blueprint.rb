class InvoiceBlueprint < Blueprinter::Base
  identifier :id

  fields :invoice_number, :status, :issue_date, :due_date, :currency_code,
    :subtotal_minor, :total_minor

  field :business do |invoice|
    {
      id: invoice.workspace.id,
      name: invoice.workspace.name
    }
  end

  field :customer do |invoice|
    if invoice.contact
      {
        id: invoice.contact.id,
        name: invoice.contact.name,
        email: invoice.contact.email,
        phone: invoice.contact.phone
      }
    end
  end

  association :invoice_lines, name: :lines, blueprint: InvoiceLineBlueprint
end
