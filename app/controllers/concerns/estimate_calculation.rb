module EstimateCalculation
  private
    def calculation_params
      params.expect(estimate: [ :currency_code, line_items_attributes: [ [ :description, :quantity, :rate ] ] ])
    end
end
