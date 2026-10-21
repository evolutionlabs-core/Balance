class JournalEntryDrafts::PostingsController < ApplicationController
  def create
    @draft = current_workspace.journal_entry_drafts.find(params[:journal_entry_draft_id])

    if @draft.posted? || @draft.post!
      redirect_to journal_entry_path(@draft.posted_entry)
    else
      @entry_form = @draft.entry_form
      @entry_form.validate
      render "journal_entry_drafts/show", status: :unprocessable_content
    end
  end
end
