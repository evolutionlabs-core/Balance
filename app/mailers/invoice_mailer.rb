class InvoiceMailer < ApplicationMailer
  helper :ui

  def issued
    @invoice = params[:invoice]
    @message = params[:message]
    @link = client_invoice_url(@invoice.generate_token_for(:client_view))
    delivery = InvoiceDelivery.new(invoice: @invoice)

    attachments["invoice-#{@invoice.invoice_number}.pdf"] = Pdf::Invoice.new(@invoice).render

    mail to: params[:to], subject: params[:subject], reply_to: delivery.sender_email.presence,
      from: email_address_with_name(self.class.default[:from], delivery.sender_name)
  end
end
