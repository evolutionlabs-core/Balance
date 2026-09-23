class InvoiceReceiptsController < ApplicationController
  before_action :set_invoice
  before_action :ensure_outstanding_invoice
  before_action :set_receipt_accounts

  def new
  end

  def create
    result = @invoice.record_receipt(
      account: @receipt_accounts.find_by(id: receipt_params[:account_id]),
      received_on: receipt_params[:received_on],
      amount_kobo: (receipt_params[:amount].to_d * 100).round
    )

    if result.success?
      redirect_out_of_frame invoice_path(@invoice), notice: "Payment recorded for invoice #{@invoice.invoice_number}."
    else
      @invoice.errors.add(:base, result.errors.to_sentence) if @invoice.errors.empty?
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.includes(:customer, :receivable_applications).find(params[:invoice_id])
    end

    def ensure_outstanding_invoice
      return if @invoice.posted? && @invoice.balance_due_kobo.positive?

      redirect_to invoice_path(@invoice), alert: "Only an issued invoice with a balance can receive payment."
    end

    def set_receipt_accounts
      @receipt_accounts = current_workspace.receipt_accounts
    end

    def receipt_params
      params.expect(invoice_receipt: [ :account_id, :received_on, :amount ])
    end
end
