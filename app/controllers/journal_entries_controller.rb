class JournalEntriesController < ApplicationController
  def index
    @ledger_entries = (current_workspace.ledgers.first&.ledger_entries || LedgerEntry.none)
      .includes(ledger_lines: :ledger_account)
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
      @ledger_entries = @ledger_entries.left_joins(ledger_lines: :ledger_account)
        .where("ledger_entries.description ILIKE :term OR ledger_accounts.name ILIKE :term", term: term)
        .distinct
    end
    @ledger_entries = @ledger_entries.where(effective_date: parsed_date_range) if parsed_date_range
    @ledger_entries = @ledger_entries.order(effective_date: :desc, id: :desc)
  end

  def new
    @journal_entry = current_workspace.journal_entries.build
    2.times { @journal_entry.journal_entry_lines.build }
  end

  def create
    @journal_entry = current_workspace.journal_entries.build(journal_entry_params)
    result = Accounting::PostingService.call(entry: @journal_entry)

    if result.success?
      respond_to do |format|
        format.html { redirect_to journal_entries_path, notice: "Journal entry recorded." }
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
    rescue Date::Error
      nil
    end

    def journal_entry_params
      params.expect(journal_entry: [
        :entry_date, :description,
        journal_entry_lines_attributes: [ [ :id, :account_id, :debit, :credit, :_destroy ] ]
      ])
    end
end
