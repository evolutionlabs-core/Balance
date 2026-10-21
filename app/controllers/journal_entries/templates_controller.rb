class JournalEntries::TemplatesController < ApplicationController
  before_action :set_entry

  def new
    @template = EntryTemplate.from_entry(@entry, user: Current.user, name: @entry.description)
  end

  def create
    @template = EntryTemplate.from_entry(@entry, user: Current.user, name: params.dig(:entry_template, :name))

    if @template.save
      redirect_out_of_frame entry_templates_path
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_entry
      @entry = current_workspace.ledger.journal_entries.includes(:journal_entry_lines).find(params[:journal_entry_id])
      redirect_to journal_entry_path(@entry) unless @entry.templatable?
    end
end
