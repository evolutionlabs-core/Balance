class Invoices::CustomersController < ApplicationController
  before_action :set_invoice
  before_action :set_customer, only: %i[edit update]

  def index
    @customers = current_workspace.customers.active.ordered
    if params[:query].present?
      @customers = @customers.where("name ILIKE ?", "%#{Customer.sanitize_sql_like(params[:query])}%")
    end
  end

  def new
    @customer = current_workspace.customers.build(active: true)
  end

  def create
    @customer = current_workspace.customers.build(customer_params)

    if @customer.save
      apply_customer
      render :refresh
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def show
    @customer = current_workspace.customers.active.find(params[:id])
    @invoice.customer = @customer
    @invoice.use_customer_details
    render :refresh
  end

  def update
    if @customer.update(customer_params)
      apply_customer
      render :refresh
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_invoice
      @invoice = if params[:invoice_id].present?
        current_workspace.invoices.find(params[:invoice_id])
      else
        current_workspace.invoices.build
      end
    end

    def set_customer
      @customer = current_workspace.customers.find(params[:id])
    end

    def apply_customer
      if @invoice.persisted?
        @invoice.change_customer(@customer)
      else
        @invoice.customer = @customer
        @invoice.use_customer_details
      end
    end

    def customer_params
      params.expect(customer: [ :name, :customer_type, :email, :phone, :address ])
    end
end
