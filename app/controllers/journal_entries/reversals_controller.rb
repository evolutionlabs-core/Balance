class JournalEntries::ReversalsController < ApplicationController
  before_action :set_entry
  before_action :ensure_reversible

  def new
    @reversal = JournalEntries::Reversal.new(entry: @entry, effective_date: Date.current)
  end

  def create
    @reversal = JournalEntries::Reversal.new(entry: @entry, **reversal_params)

    if @reversal.record!
      redirect_out_of_frame journal_entry_path(@entry)
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_entry
      @entry = current_workspace.ledger.journal_entries.includes(journal_entry_lines: :account).find(params[:journal_entry_id])
    end

    def ensure_reversible
      return if @entry.reversible?

      redirect_to journal_entry_path(@entry), alert: "Entry ##{@entry.number} cannot be reversed here."
    end

    def reversal_params
      params.expect(reversal: %i[effective_date description]).to_h.symbolize_keys
    end
end
