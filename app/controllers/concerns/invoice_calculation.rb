module InvoiceCalculation
  private
    def calculation_params
      params.expect(invoice: [ :currency_code, invoice_lines_attributes: [ [ :description, :quantity, :rate ] ] ])
    end
end
