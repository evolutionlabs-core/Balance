class Invoices::PaymentReversalsController < ApplicationController
  def create
    invoice = current_workspace.invoices.find(params[:invoice_id])
    payment = invoice.payments.find(params[:payment_id])

    if invoice.reverse_payment!(payment)
      redirect_to invoice_path(invoice), notice: "Payment reversed. Invoice #{invoice.invoice_number} is open again."
    else
      redirect_to invoice_path(invoice), alert: invoice.errors.full_messages.to_sentence
    end
  end
end
