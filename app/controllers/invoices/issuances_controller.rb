module Invoices
  class IssuancesController < ApplicationController
    before_action :set_invoice
    before_action :ensure_draft, only: %i[new create]

    def new
    end

    def create
      if @invoice.issue!
        redirect_out_of_frame invoice_path(@invoice), notice: "Invoice #{@invoice.invoice_number} sent."
      else
        @invoice.errors.add(:base, "Invoice cannot be sent.") if @invoice.errors.empty?
        render :new, status: :unprocessable_content
      end
    end

    private
      def set_invoice
        @invoice = current_workspace.invoices.includes(:customer, :invoice_lines).find(params[:invoice_id])
      end

      def ensure_draft
        return if @invoice.draft?

        redirect_to invoice_path(@invoice), alert: "Only draft invoices can be sent."
      end
  end
end
