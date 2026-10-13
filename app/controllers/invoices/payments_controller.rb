class Invoices::PaymentsController < ApplicationController
  before_action :set_invoice
  before_action :ensure_payable_invoice
  before_action :set_payment_accounts

  def new
  end

  def create
    if @invoice.record_payment!(
      payment_ledger_account_id: payment_params[:payment_ledger_account_id],
      received_on: parsed_received_on,
      amount_kobo: (payment_params[:amount].to_d * 100).round
    )
      redirect_out_of_frame invoice_path(@invoice), notice: "Payment recorded for invoice #{@invoice.invoice_number}."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.includes(:customer, :payments).find(params[:invoice_id])
    end

    def ensure_payable_invoice
      return if @invoice.sent? && @invoice.balance_due_kobo.positive?

      redirect_to invoice_path(@invoice), alert: "Only a sent invoice with a balance can receive payment."
    end

    def set_payment_accounts
      @payment_accounts = current_workspace.payment_accounts
    end

    def payment_params
      params.expect(invoice_payment: [ :payment_ledger_account_id, :received_on, :amount ])
    end

    def parsed_received_on
      Date.parse(payment_params[:received_on].to_s)
    rescue Date::Error
      nil
    end
end
