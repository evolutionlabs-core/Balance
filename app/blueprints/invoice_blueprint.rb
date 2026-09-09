class InvoiceBlueprint < Blueprinter::Base
  identifier :id

  fields :status, :issue_date, :due_date, :currency_code,
    :subtotal_minor, :total_minor, :business_name, :business_email,
    :business_address, :bill_to_name, :bill_to_email, :bill_to_address

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
