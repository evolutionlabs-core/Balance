module Invoices
  class IssuancesController < ApplicationController
    before_action :set_invoice
    before_action :ensure_draft

    def new
      @delivery = InvoiceDelivery.new(invoice: @invoice)
    end

    def create
      @delivery = InvoiceDelivery.new(invoice: @invoice, **delivery_params)

      if @delivery.send_email && @delivery.invalid?
        render :new, status: :unprocessable_content
      elsif @invoice.issue!
        @delivery.deliver_later if @delivery.send_email
        redirect_to invoice_path(@invoice), notice: sent_notice
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

      def delivery_params
        params.fetch(:delivery, {}).permit(:to, :subject, :message, :send_email).to_h.symbolize_keys
      end

      def sent_notice
        if @delivery.send_email
          "Invoice #{@invoice.invoice_number} sent to #{@delivery.to}."
        else
          "Invoice #{@invoice.invoice_number} marked as sent."
        end
      end
  end
end
