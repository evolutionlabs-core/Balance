class VendorsController < ApplicationController
  include BusinessWorkspace

  before_action :set_vendor, only: %i[show edit update]

  def index
    @pagy, @vendors = pagy(current_workspace.vendors.ordered.order(:id))
  end

  def new
    @vendor = current_workspace.vendors.build(active: true)
  end

  def create
    @vendor = current_workspace.vendors.build(vendor_params)

    if @vendor.save
      redirect_out_of_frame vendors_path, notice: "Vendor created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @bills = @vendor.bills.includes(:payments).order(created_at: :desc)
  end

  def edit
  end

  def update
    if @vendor.update(vendor_params)
      redirect_out_of_frame vendors_path, notice: "Vendor updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_vendor
      @vendor = current_workspace.vendors.find(params[:id])
    end

    def vendor_params
      params.expect(vendor: [ :name, :email, :phone, :address, :active ])
    end
end
