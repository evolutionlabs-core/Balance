class InvoiceForms::LinesController < ApplicationController
  include InvoiceCalculation

  def new
    @index = SecureRandom.random_number(10**18)
    @line = InvoiceLine.new
  end

  def destroy
    attributes = calculation_params
    attributes[:invoice_lines_attributes].delete(params[:id])
    @calculation = Invoice::Calculation.new(current_workspace, Current.user, attributes)
  end
end
