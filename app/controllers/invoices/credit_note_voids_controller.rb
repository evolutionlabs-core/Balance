class Invoices::CreditNoteVoidsController < ApplicationController
  def create
    invoice = current_workspace.invoices.find(params[:invoice_id])
    credit_note = invoice.credit_notes.find(params[:credit_note_id])

    if invoice.void_credit_note!(credit_note)
      redirect_to invoice_path(invoice)
    else
      redirect_to invoice_path(invoice), alert: invoice.errors.full_messages.to_sentence
    end
  end
end
