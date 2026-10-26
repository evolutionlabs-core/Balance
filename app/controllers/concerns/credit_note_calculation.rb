module CreditNoteCalculation
  private
    def calculation_params
      params.expect(credit_note: [ :discount_type, :discount_value, lines_attributes: [ [ :service_id, :description, :quantity, :rate, :amount ] ] ])
    end
end
