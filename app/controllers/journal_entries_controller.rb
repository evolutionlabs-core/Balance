class JournalEntriesController < ApplicationController
  def index
    @ledger_entries = (current_workspace.ledgers.first&.ledger_entries || LedgerEntry.none)
      .includes(ledger_lines: :ledger_account)
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
      @ledger_entries = @ledger_entries
        .left_joins(ledger_lines: :ledger_account)
        .where("ledger_entries.description ILIKE :term OR ledger_accounts.name ILIKE :term", term: term)
        .distinct
    end
    @ledger_entries = @ledger_entries.where(effective_date: parsed_date_range) if parsed_date_range
    @ledger_entries = @ledger_entries.order(effective_date: :desc, id: :desc)
  end

  def new
    @entry_form = LedgerEntries::ManualEntry.new(workspace: current_workspace, effective_date: Date.current)
    2.times { @entry_form.build_line }
  end

  def create
    @entry_form = LedgerEntries::ManualEntry.new(workspace: current_workspace, **entry_params)

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
        { lines: [ [ :ledger_account_id, :debit, :credit, :_destroy ] ] }
      ])
    end
end
