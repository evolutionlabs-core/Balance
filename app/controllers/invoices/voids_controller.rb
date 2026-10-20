class Invoices::VoidsController < ApplicationController
  before_action :set_invoice
  before_action :ensure_voidable

  def new
  end

  def create
    if @invoice.void!
      redirect_out_of_frame invoice_path(@invoice), notice: "Invoice #{@invoice.invoice_number} voided."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.includes(:customer, :invoice_lines).find(params[:invoice_id])
    end

    def ensure_voidable
      return if @invoice.may_mark_voided?

      redirect_to invoice_path(@invoice), alert: "Invoice #{@invoice.invoice_number} cannot be voided."
    end
end
