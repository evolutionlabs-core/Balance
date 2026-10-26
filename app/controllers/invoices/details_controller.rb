class Invoices::DetailsController < ApplicationController
  before_action :set_invoice
  before_action :ensure_revisable

  def edit
  end

  def update
    if @invoice.revise(details_params)
      redirect_out_of_frame invoice_path(@invoice)
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.find(params[:invoice_id])
    end

    def ensure_revisable
      return if @invoice.revisable?

      redirect_to invoice_path(@invoice), alert: "Only sent invoices can have their details changed."
    end

    def details_params
      params.expect(invoice: Invoice::EDITABLE_AFTER_SENDING.map(&:to_sym))
    end
end
