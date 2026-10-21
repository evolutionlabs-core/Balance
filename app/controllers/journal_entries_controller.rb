class JournalEntriesController < ApplicationController
  def index
    @journal_entries = (current_workspace.ledgers.first&.journal_entries || JournalEntry.none)
      .includes(:reversal, journal_entry_lines: :account)
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
      @journal_entries = @journal_entries
        .left_joins(journal_entry_lines: :account)
        .where("journal_entries.description ILIKE :term OR accounts.name ILIKE :term", term: term)
        .distinct
    end
    @journal_entries = @journal_entries.where(effective_date: parsed_date_range) if parsed_date_range
    @journal_entries = @journal_entries.order(effective_date: :desc, id: :desc)
  end

  def show
    @entry = current_workspace.ledger.journal_entries
      .includes(:posted_by, :reverses_entry, :reversal, journal_entry_lines: %i[account customer vendor])
      .find(params[:id])
  end

  def new
    @entry_form = JournalEntries::ManualEntry.new(workspace: current_workspace, effective_date: Date.current)
    2.times { @entry_form.build_line }
  end

  def create
    @entry_form = JournalEntries::ManualEntry.new(workspace: current_workspace, **entry_params)

    if @entry_form.record!
      respond_to do |format|
        format.html { redirect_to journal_entries_path, notice: "Entry recorded." }
        format.turbo_stream { render turbo_stream: turbo_stream.action(:redirect, journal_entries_path) }
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def parsed_date_range
      return if params[:from].blank? || params[:to].blank?

      Date.iso8601(params[:from])..Date.iso8601(params[:to])
    end

    def entry_params
      params.expect(entry: [
        :effective_date, :description,
        { lines: [ [ :account_id, :debit, :credit, :_destroy ] ] }
      ])
    end
end
