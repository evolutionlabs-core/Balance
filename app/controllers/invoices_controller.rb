class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show edit update]
  before_action :ensure_draft, only: %i[edit update]
  before_action :set_services, only: %i[new create edit update]

  def index
    @invoices = current_workspace.invoices.includes(:customer, :payments).order(created_at: :desc)
  end

  def new
    @invoice = current_workspace.invoices.build(
      user: Current.user,
      currency_code: current_workspace.currency_code
    )
    2.times { @invoice.invoice_lines.build }
    @invoice.populate_party_details
  end

  def create
    @invoice = current_workspace.invoices.build(invoice_params)
    @invoice.user = Current.user

    if @invoice.save
      redirect_to invoice_path(@invoice), notice: "Invoice draft saved."
    else
      @invoice.invoice_lines.build if @invoice.invoice_lines.empty?
      render :new, status: :unprocessable_content
    end
  end

  def show
    respond_to do |format|
      format.html do
        @delivery = InvoiceDelivery.new(invoice: @invoice) if @invoice.draft?
        @view = params[:view].presence_in(@delivery ? %w[customer email pdf] : %w[customer pdf]) || "customer"
      end
      format.pdf do
        send_data Pdf::Invoice.new(@invoice).render, filename: "invoice-#{@invoice.id}.pdf",
          type: "application/pdf", disposition: params[:disposition] == "inline" ? "inline" : "attachment"
      end
    end
  end

  def edit
    @invoice.invoice_lines.build if @invoice.invoice_lines.empty?
  end

  def update
    if @invoice.update(invoice_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to invoice_path(@invoice), notice: "Invoice draft saved." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :update, status: :unprocessable_content }
        format.html do
          render :edit, status: :unprocessable_content
        end
      end
    end
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.includes(:workspace, :customer, :invoice_lines, :payments).find(params[:id])
    end

    def ensure_draft
      return if @invoice.draft?

      redirect_to invoice_path(@invoice), alert: "Only draft invoices can be changed."
    end

    def invoice_params
      params.expect(invoice: [
        :customer_id, :issue_date, :due_date,
        :business_name, :business_email, :business_address,
        :bill_to_name, :bill_to_email, :bill_to_address,
        invoice_lines_attributes: [ [ :id, :service_id, :description, :quantity, :rate, :rate_minor, :_destroy ] ]
      ])
    end

    def set_services
      @services = current_workspace.services.ordered.to_a
    end
end
