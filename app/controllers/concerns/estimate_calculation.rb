module EstimateCalculation
  private
    def calculation_params
      params.expect(estimate: [ :currency_code, line_items_attributes: [ [ :service_id, :description, :quantity, :rate, :amount ] ] ])
    end
end
