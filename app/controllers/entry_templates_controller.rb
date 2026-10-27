class EntryTemplatesController < ApplicationController
  def index
    @pagy, @templates = pagy(current_workspace.entry_templates.ordered.order(:id))
    @accounts = current_workspace.accounts.where(id: @templates.flat_map { |template| template.lines.map { |line| line["account_id"] } }).index_by(&:id)
  end

  def destroy
    current_workspace.entry_templates.find(params[:id]).destroy!
    redirect_to entry_templates_path
  end
end
