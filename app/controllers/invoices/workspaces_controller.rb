class Invoices::WorkspacesController < ApplicationController
  before_action :set_invoice

  def edit
    @workspace = current_workspace
  end

  def update
    @workspace = current_workspace

    if @workspace.update(workspace_params)
      if @invoice&.persisted?
        @invoice.refresh_business_details
      else
        @invoice = current_workspace.invoices.build(user: Current.user)
        @invoice.populate_party_details
      end
      render :refresh
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.find(params[:invoice_id]) if params[:invoice_id].present?
    end

    def workspace_params
      params.expect(workspace: [ :name, :address ])
    end
end
