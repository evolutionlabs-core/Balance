class ServicesController < ApplicationController
  before_action :set_service, only: %i[edit update]

  def index
    @services = current_workspace.services.includes(:income_account).ordered
  end

  def new
    @service = current_workspace.services.build(active: true)
  end

  def create
    @service = current_workspace.services.build(service_params)

    if @service.save
      redirect_out_of_frame services_path, notice: "Service created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @service.update(service_params)
      redirect_out_of_frame services_path, notice: "Service updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_service
      @service = current_workspace.services.find(params[:id])
    end

    def service_params
      params.expect(service: [ :name, :description, :default_rate, :income_account_id, :active ])
    end
end
