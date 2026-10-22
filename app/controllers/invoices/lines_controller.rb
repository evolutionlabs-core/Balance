class Invoices::LinesController < ApplicationController
  include InvoiceCalculation

  def new
    @index = SecureRandom.random_number(10**18)
    @line = InvoiceLine.new(quantity: 1)
    @services = current_workspace.services.ordered.to_a
  end

  def destroy
    @services = current_workspace.services.ordered.to_a
    attributes = calculation_params
    attributes[:invoice_lines_attributes].delete(params[:id])
    @calculation = Invoice::Calculation.new(current_workspace, Current.user, attributes)
  end
end
