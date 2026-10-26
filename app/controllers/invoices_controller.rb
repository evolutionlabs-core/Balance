class InvoicesController < ApplicationController
  include InvoiceParams

  before_action :set_invoice, only: %i[show edit update]
  before_action :ensure_draft, only: %i[edit update]
  before_action :set_services, only: %i[new create edit update]

  STATUS_FILTERS = {
    "overdue" => "Overdue",
    "not_due" => "Not due",
    "draft" => "Draft",
    "paid" => "Paid",
    "voided" => "Voided"
  }.freeze

  def index
    @summary = InvoiceSummary.new(current_workspace)
    @status = params[:status].presence_in(STATUS_FILTERS.keys)
    @invoices = filtered_invoices.includes(:customer, :payments, :credit_notes).order(created_at: :desc, id: :desc)
  end

  def new
    @invoice = current_workspace.invoices.build(
      user: Current.user,
      currency_code: current_workspace.currency_code,
      issue_date: Date.current
    )
    @invoice.invoice_lines.build(quantity: 1)
    @invoice.populate_party_details
    @invoice.apply_workspace_defaults
    @invoice.due_date = PaymentTerms.due_date(@invoice.payment_terms, @invoice.issue_date)
  end

  def create
    @invoice = current_workspace.invoices.build(invoice_params)
    @invoice.user = Current.user

    if @invoice.save
      redirect_to invoice_path(@invoice, view: ("email" if params[:next] == "send")), notice: "Invoice draft saved."
    else
      @invoice.invoice_lines.build(quantity: 1) if @invoice.invoice_lines.empty?
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
    @invoice.invoice_lines.build(quantity: 1) if @invoice.invoice_lines.empty?
  end

  def update
    if @invoice.update(invoice_params)
      @dates_changed = @invoice.saved_change_to_due_date? || @invoice.saved_change_to_payment_terms?
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
    def filtered_invoices
      invoices = current_workspace.invoices
      invoices = case @status
      when "overdue", "not_due" then invoices.public_send(@status)
      when nil then invoices
      else invoices.where(status: @status)
      end

      if params[:q].present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
        invoices = invoices.left_joins(:customer).where("invoices.invoice_number ILIKE :term OR customers.name ILIKE :term", term: term)
      end

      invoices = invoices.where(issue_date: issue_date_range) if issue_date_range
      invoices
    end

    def issue_date_range
      return if params[:from].blank? || params[:to].blank?

      Date.iso8601(params[:from])..Date.iso8601(params[:to])
    rescue Date::Error
      nil
    end

    def set_invoice
      @invoice = current_workspace.invoices.includes(:workspace, :customer, :invoice_lines, :payments, :credit_notes, revisions: :user).find(params[:id])
    end

    def ensure_draft
      return if @invoice.draft?

      redirect_to invoice_path(@invoice), alert: "Only draft invoices can be changed."
    end

    def set_services
      @services = current_workspace.services.ordered.to_a
    end
end
