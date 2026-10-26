module CreditNoteCalculation
  private
    def calculation_params
      params.expect(credit_note: [ :invoice_id, lines_attributes: [ [ :service_id, :description, :quantity, :rate, :amount ] ] ])
    end
end
