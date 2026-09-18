class Estimate::Calculation
  attr_reader :estimate, :lines

  def initialize(workspace, user, attributes)
    attributes = attributes.to_h
    @lines = attributes.fetch(:line_items_attributes, {}).transform_values { |line| EstimateLineItem.new(line) }
    @estimate = workspace.estimates.build(user: user, currency_code: attributes[:currency_code])
    @estimate.line_items = lines.values
    @estimate.valid?
  end
end
