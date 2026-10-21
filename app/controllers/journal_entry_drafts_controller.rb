class JournalEntryDraftsController < ApplicationController
  before_action :set_draft, only: %i[show edit update destroy]
  before_action :ensure_unposted, only: %i[show edit update destroy]

  def index
    @drafts = current_workspace.journal_entry_drafts.unposted.includes(:user).order(updated_at: :desc)
  end

  def show
    @entry_form = @draft.entry_form
    @entry_form.validate
  end

  def create
    @draft = current_workspace.journal_entry_drafts.build(user: Current.user)
    @draft.assign_form(draft_params)
    save_and_continue
  end

  def edit
    @entry_form = @draft.entry_form
  end

  def update
    @draft.assign_form(draft_params)
    save_and_continue
  end

  def destroy
    @draft.destroy!
    redirect_to journal_entry_drafts_path
  end

  private
    def set_draft
      @draft = current_workspace.journal_entry_drafts.find(params[:id])
    end

    def ensure_unposted
      redirect_to journal_entry_path(@draft.posted_entry) if @draft.posted?
    end

    def save_and_continue
      @entry_form = @draft.entry_form

      if reviewing? && @entry_form.invalid?
        render (@draft.persisted? ? :edit : "journal_entries/new"), status: :unprocessable_content
      else
        @draft.save!
        redirect_out_of_frame reviewing? ? journal_entry_draft_path(@draft) : journal_entry_drafts_path
      end
    end

    def reviewing?
      params[:intent] == "review"
    end

    def draft_params
      params.expect(entry: [ :effective_date, :description, { lines: [ [ :account_id, :debit, :credit, :_destroy ] ] } ])
    end
end
