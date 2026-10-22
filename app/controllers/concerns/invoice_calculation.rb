module InvoiceCalculation
  private
    def calculation_params
      params.expect(invoice: [ :currency_code, :discount_type, :discount_value, invoice_lines_attributes: [ [ :service_id, :description, :quantity, :rate, :amount ] ] ])
    end
end
