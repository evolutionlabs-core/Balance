class InvoicePostingsController < ApplicationController
  before_action :set_invoice
  before_action :ensure_draft, only: %i[new create]

  def new
  end

  def create
    result = @invoice.issue

    if result.success?
      redirect_out_of_frame invoice_path(@invoice), notice: "Invoice #{@invoice.invoice_number} issued."
    else
      @invoice.errors.add(:base, result.errors.to_sentence) if @invoice.errors.empty?
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.includes(:customer, :invoice_lines).find(params[:invoice_id])
    end

    def ensure_draft
      return unless @invoice.posted?

      redirect_to invoice_path(@invoice), alert: "Posted invoices cannot be changed."
    end
end
