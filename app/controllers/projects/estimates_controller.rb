class Projects::EstimatesController < ApplicationController
  before_action :set_project, only: %i[index new create]
  before_action :set_estimate, only: %i[show edit update destroy]
  before_action :ensure_editable, only: %i[edit update destroy]
  before_action :set_services, only: %i[new create edit update]

  def index
    @estimates = @project.estimates.includes(:customer).ordered
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        send_data Estimate::Pdf.new(@estimate).render, filename: "estimate-#{@estimate.id}.pdf",
          type: "application/pdf", disposition: "attachment"
      end
    end
  end

  def new
    @estimate = @project.estimates.build(
      user: Current.user,
      customer: @project.customer,
      currency_code: @project.currency_code
    )
    @estimate.use_customer_details
    2.times { @estimate.line_items.build }
  end

  def create
    @estimate = @project.estimates.build(estimate_params)
    @estimate.user = Current.user
    @estimate.customer = @project.customer
    @estimate.workspace = current_workspace

    if @estimate.save
      redirect_out_of_frame project_estimate_path(@estimate), notice: "Estimate #{@estimate.number} created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    2.times { @estimate.line_items.build }
  end

  def update
    if @estimate.update(estimate_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_out_of_frame project_estimate_path(@estimate), notice: "Estimate saved." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :update, status: :unprocessable_content }
        format.html { render :edit, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @estimate.destroy!
    redirect_to project_project_estimates_path(@project), notice: "Estimate removed."
  end

  private
    def set_project
      @project = current_workspace.projects.includes(:customer).find(params[:project_id])
    end

    def set_estimate
      @estimate = current_workspace.estimates.find(params[:id])
      @project = @estimate.project
    end

    def ensure_editable
      return unless @estimate.invoiced?

      redirect_to project_estimate_path(@estimate), alert: "Invoiced estimates are read-only."
    end

    def estimate_params
      params.expect(estimate: [
        :currency_code, :bill_to_name, :bill_to_email, :bill_to_address,
        :business_name, :business_email, :business_address, :notes,
        line_items_attributes: [ [ :id, :service_id, :description, :quantity, :rate, :_destroy ] ]
      ])
    end

    def set_services
      @services = current_workspace.services.ordered.to_a
    end
end
