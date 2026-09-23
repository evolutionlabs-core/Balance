class InvoicePostingsController < ApplicationController
  before_action :set_invoice
  before_action :ensure_draft, only: %i[new create]
  before_action :set_income_accounts

  def new
  end

  def create
    receivable_account = Account.for_role!(current_workspace, :receivable)
    attributes = params.fetch(:invoice, ActionController::Parameters.new).permit(invoice_lines_attributes: [ :id, :account_id ])
    result = @invoice.post(receivable_account: receivable_account,
      line_accounts: attributes.fetch(:invoice_lines_attributes, []))

    if result.success?
      redirect_out_of_frame invoice_path(@invoice), notice: "Invoice #{@invoice.invoice_number} posted."
    else
      @invoice.errors.add(:base, result.errors.to_sentence) if @invoice.errors.empty?
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_income_accounts
      @income_accounts = current_workspace.accounts.where(base_type: "income").ordered
    end

    def set_invoice
      @invoice = current_workspace.invoices.includes(:customer, :invoice_lines).find(params[:invoice_id])
    end

    def ensure_draft
      return unless @invoice.posted?

      redirect_to invoice_path(@invoice), alert: "Posted invoices cannot be changed."
    end
end
