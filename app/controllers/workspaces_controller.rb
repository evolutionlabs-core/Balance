class WorkspacesController < ApplicationController
  before_action :set_invoice, if: -> { params[:invoice_id].present? }

  def edit
    @workspace = current_workspace
  end

  def update
    @workspace = current_workspace

    if @workspace.update(workspace_params)
      if @invoice
        @invoice.refresh_business_details
        render :update
      elsif params[:invoice_context] == "new"
        @invoice = current_workspace.invoices.build(user: Current.user)
        @invoice.valid?
        render :update
      else
        redirect_to dashboard_path, notice: "Workspace updated."
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_invoice
      @invoice = current_workspace.invoices.find(params[:invoice_id])
    end

    def workspace_params
      params.expect(workspace: [ :name, :address ])
    end
end
