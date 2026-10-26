class CreditNoteCalculationsController < ApplicationController
  include CreditNoteCalculation

  def create
    @calculation = CreditNote::Calculation.new(current_workspace, Current.user, calculation_params)
  end
end
