class WorkspacesController < ApplicationController
  def edit
    @workspace = current_workspace
  end

  def update
    @workspace = current_workspace

    if @workspace.update(workspace_params)
      redirect_to overview_path, notice: "Workspace updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def workspace_params
      params.expect(workspace: [ :name, :address, :default_sales_account_id, :default_deposit_account_id,
        :default_payment_terms, :payment_instructions, :default_invoice_note ])
    end
end
