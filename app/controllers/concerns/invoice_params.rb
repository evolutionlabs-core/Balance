module InvoiceParams
  private
    def invoice_params
      params.expect(invoice: [
        :customer_id, :issue_date, :due_date, :payment_terms, :reference,
        :notes, :internal_note, :payment_instructions, :discount_type, :discount_value,
        :business_name, :business_email, :business_address,
        :bill_to_name, :bill_to_email, :bill_to_address,
        invoice_lines_attributes: [ [ :id, :service_id, :description, :quantity, :rate, :rate_minor, :_destroy ] ]
      ])
    end
end
