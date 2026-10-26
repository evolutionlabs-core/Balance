class Invoices::CreditNotesController < ApplicationController
  before_action :set_invoice
  before_action :ensure_creditable_invoice

  def new
  end

  def create
    if @invoice.issue_credit_note!(
      amount_minor: MoneyInput.to_kobo(credit_note_params[:amount]),
      issued_on: parsed_issued_on,
      reason: credit_note_params[:reason],
      user: Current.user
    )
      redirect_out_of_frame invoice_path(@invoice)
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.includes(:customer, :payments, :credit_notes).find(params[:invoice_id])
    end

    def ensure_creditable_invoice
      return if @invoice.sent? && @invoice.balance_due_kobo.positive?

      redirect_to invoice_path(@invoice), alert: "Only a sent invoice with a balance can be credited."
    end

    def credit_note_params
      params.expect(credit_note: [ :issued_on, :amount, :reason ])
    end

    def parsed_issued_on
      Date.parse(credit_note_params[:issued_on].to_s)
    rescue Date::Error
      nil
    end
end
