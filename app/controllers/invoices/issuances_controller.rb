module Invoices
  class IssuancesController < ApplicationController
    before_action :set_invoice
    before_action :ensure_draft

    def create
      if @invoice.issue!
        redirect_to invoice_path(@invoice), notice: "Invoice #{@invoice.invoice_number} sent."
      else
        redirect_to invoice_path(@invoice), alert: @invoice.errors.full_messages.to_sentence.presence || "Invoice cannot be sent."
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
