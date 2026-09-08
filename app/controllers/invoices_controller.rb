class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show update]

  def create
    @invoice = current_workspace.invoices.build(invoice_params)
    @invoice.user = Current.user

    if @invoice.save
      render json: InvoiceBlueprint.render_as_json(@invoice), status: :created
    else
      render json: { errors: @invoice.errors.full_messages }, status: :unprocessable_content
    end
  end

  def show
    render json: InvoiceBlueprint.render_as_json(@invoice)
  end

  def update
    if @invoice.update(invoice_params)
      render json: InvoiceBlueprint.render_as_json(@invoice)
    else
      render json: { errors: @invoice.errors.full_messages }, status: :unprocessable_content
    end
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.includes(:workspace, :contact, :invoice_lines).find(params[:id])
    end

    def invoice_params
      params.expect(invoice: [
        :contact_id, :invoice_number, :issue_date, :due_date, :currency_code,
        invoice_lines_attributes: [ [ :id, :description, :quantity, :rate_minor, :_destroy ] ]
      ])
    end
end
