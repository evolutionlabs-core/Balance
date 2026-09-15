class CustomersController < ApplicationController
  before_action :set_customer, only: %i[show edit update]

  def index
    @customers = current_workspace.customers.ordered
  end

  def new
    @customer = current_workspace.customers.build(active: true)
  end

  def create
    @customer = current_workspace.customers.build(customer_params)

    if @customer.save
      redirect_out_of_frame customers_path, notice: "Customer created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_out_of_frame customers_path, notice: "Customer updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def show
  end

  private
    def set_customer
      @customer = current_workspace.customers.find(params[:id])
    end

    def customer_params
      params.expect(customer: [
        :name, :customer_type, :email, :phone, :active,
        :address
      ])
    end
end
