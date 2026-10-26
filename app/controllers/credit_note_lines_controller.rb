class CreditNoteLinesController < ApplicationController
  include CreditNoteCalculation

  def new
    @index = SecureRandom.random_number(10**18)
    @line = CreditNoteLine.new(quantity: 1)
    @services = current_workspace.services.ordered.to_a
  end

  def destroy
    attributes = calculation_params
    attributes[:lines_attributes].delete(params[:id])
    @calculation = CreditNote::Calculation.new(current_workspace, Current.user, attributes)
  end
end
