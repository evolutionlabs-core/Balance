class Invoices::SettlementsController < ApplicationController
  def create
    invoice = current_workspace.invoices.includes(:customer, :payments).find(params[:invoice_id])
    amount_kobo = invoice.balance_due_kobo

    if invoice.sent? && amount_kobo.positive? && invoice.mark_paid!
      redirect_to invoice_path(invoice), notice: "#{helpers.naira(amount_kobo)} received into #{current_workspace.default_deposit_account.name}."
    else
      redirect_to invoice_path(invoice), alert: invoice.errors.full_messages.to_sentence.presence || "Only a sent invoice with a balance can be marked as paid."
    end
  end
end
