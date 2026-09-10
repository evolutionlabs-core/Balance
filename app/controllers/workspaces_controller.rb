class WorkspacesController < ApplicationController
  def edit
    @workspace = current_workspace
  end

  def update
    @workspace = current_workspace

    if @workspace.update(workspace_params)
      redirect_to dashboard_path, notice: "Workspace updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def workspace_params
      params.expect(workspace: [ :name, :address ])
    end
end
