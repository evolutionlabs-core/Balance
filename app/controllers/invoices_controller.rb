class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show edit update]

  def index
    @invoices = current_workspace.invoices.includes(:contact).order(created_at: :desc)
  end

  def new
    @invoice = current_workspace.invoices.build(
      user: Current.user,
      issue_date: Date.current,
      due_date: 30.days.from_now.to_date,
      currency_code: current_workspace.currency_code
    )
    2.times { @invoice.invoice_lines.build }
    @invoice.populate_party_details
  end

  def create
    @invoice = current_workspace.invoices.build(invoice_params)
    @invoice.user = Current.user

    if @invoice.save
      respond_to do |format|
        format.html { redirect_to invoice_path(@invoice), notice: "Invoice draft saved." }
        format.json { render json: InvoiceBlueprint.render_as_json(@invoice), status: :created }
      end
    else
      respond_to do |format|
        format.html do
          @invoice.invoice_lines.build if @invoice.invoice_lines.empty?
          render :new, status: :unprocessable_content
        end
        format.json { render json: { errors: @invoice.errors.full_messages }, status: :unprocessable_content }
      end
    end
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        send_data Invoice::Pdf.new(@invoice).render, filename: "invoice-#{@invoice.id}.pdf",
          type: "application/pdf", disposition: "attachment"
      end
      format.json { render json: InvoiceBlueprint.render_as_json(@invoice) }
    end
  end

  def edit
    @invoice.invoice_lines.build if @invoice.invoice_lines.empty?
  end

  def update
    if params.dig(:invoice, :invoice_lines_attributes) && !params[:preview] && request.format.turbo_stream?
      @calculation = Invoice::Calculation.new(current_workspace, Current.user, invoice_params.slice(:currency_code, :invoice_lines_attributes))
      render "invoice_forms/calculations/create"
      return
    end
    @invoice.assign_attributes(invoice_params)
    context = :editing if request.format.turbo_stream? && !params[:preview]
    if @invoice.save(context: context)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to invoice_path(@invoice), notice: "Invoice draft saved." }
        format.json { render json: InvoiceBlueprint.render_as_json(@invoice) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :update, status: :unprocessable_content }
        format.html do
          render :edit, status: :unprocessable_content
        end
        format.json { render json: { errors: @invoice.errors.full_messages }, status: :unprocessable_content }
      end
    end
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.includes(:workspace, :contact, :invoice_lines).find(params[:id])
    end

    def invoice_params
      params.expect(invoice: [
        :contact_id, :issue_date, :due_date, :currency_code,
        :business_name, :business_email, :business_address,
        :bill_to_name, :bill_to_email, :bill_to_address,
        invoice_lines_attributes: [ [ :id, :description, :quantity, :rate, :rate_minor, :_destroy ] ]
      ])
    end
end
