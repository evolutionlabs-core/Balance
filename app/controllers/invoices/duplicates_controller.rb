class Invoices::DuplicatesController < ApplicationController
  def create
    invoice = current_workspace.invoices.includes(:invoice_lines).find(params[:invoice_id])
    copy = invoice.duplicate(user: Current.user)

    if copy.save
      redirect_to edit_invoice_path(copy)
    else
      redirect_to invoice_path(invoice), alert: copy.errors.full_messages.to_sentence
    end
  end
end
