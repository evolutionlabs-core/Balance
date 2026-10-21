require "net/smtp"

module Invoices
  class IssuancesController < ApplicationController
    MAIL_ERRORS = [ Net::SMTPError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError ].freeze

    before_action :set_invoice
    before_action :ensure_draft

    def create
      @delivery = InvoiceDelivery.new(invoice: @invoice, **delivery_params)

      if @delivery.send_email && @delivery.invalid?
        @view = "email"
        render "invoices/show", status: :unprocessable_content
      elsif issue_and_deliver
        redirect_to invoice_path(@invoice), notice: sent_notice
      else
        redirect_to invoice_path(@invoice), alert: @invoice.errors.full_messages.to_sentence.presence || "Invoice cannot be sent."
      end
    end

    private
      def issue_and_deliver
        Invoice.transaction do
          raise ActiveRecord::Rollback unless @invoice.issue!

          @delivery.deliver_now if @delivery.send_email
          true
        end
      rescue *MAIL_ERRORS
        @invoice.reload.errors.add(:base, "The email couldn't be sent, so the invoice is still a draft.")
        false
      end

      def set_invoice
        @invoice = current_workspace.invoices.includes(:customer, :invoice_lines).find(params[:invoice_id])
      end

      def ensure_draft
        return if @invoice.draft?

        redirect_to invoice_path(@invoice), alert: "Only draft invoices can be sent."
      end

      def delivery_params
        params.fetch(:delivery, {}).permit(:to, :subject, :message, :send_email, :via).to_h.symbolize_keys
      end

      def sent_notice
        number = @invoice.invoice_number
        return "Invoice #{number} sent to #{@delivery.to}." if @delivery.send_email

        {
          "share" => "Invoice #{number} shared.",
          "copy" => "Invoice #{number} marked as sent."
        }.fetch(@delivery.via.to_s, "Invoice #{number} marked as sent.")
      end
  end
end
