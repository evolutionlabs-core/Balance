class Invoices::LinesController < ApplicationController
  include InvoiceScoped

  def create
    @replace_placeholder = params[:invoice_line].present? || @invoice.invoice_lines.empty?
    @line = @invoice.add_line(params[:invoice_line] ? line_params : {})
    render :create, status: :unprocessable_content if @invoice.errors.any?
  end

  def update
    saved = @invoice.change_line(params[:id], line_params)
    @line = @invoice.invoice_lines.find { |line| line.id.to_s == params[:id] }
    render :update, status: :unprocessable_content unless saved
  end

  def destroy
    @line = @invoice.remove_line(params[:id])
  end

  private
    def line_params
      params.expect(invoice_line: [ :description, :quantity, :rate ])
    end
end
