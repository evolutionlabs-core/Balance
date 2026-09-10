class InvoiceForms::CalculationsController < ApplicationController
  include InvoiceCalculation

  def create
    @calculation = Invoice::Calculation.new(current_workspace, Current.user, calculation_params)
  end
end
