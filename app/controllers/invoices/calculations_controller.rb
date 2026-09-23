class Invoices::CalculationsController < ApplicationController
  include InvoiceCalculation

  def create
    @services = current_workspace.services.ordered.to_a
    @calculation = Invoice::Calculation.new(current_workspace, Current.user, calculation_params)
  end
end
