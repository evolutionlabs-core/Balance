class ListJournalEntries < RubyLLM::Tool
  description "List recorded journal entries in this workspace. Entries the assistant recorded from chat have source \"Entry\". " \
              "reverses_journal_entry_id is present only when the entry is itself a reversal; reversed is true once an entry has been reversed."

  parameters do
    integer :limit, required: false, description: "maximum number of entries to return, from 1 to 20; defaults to 10"
    string :from_date, required: false, description: "optional inclusive ISO date filter (YYYY-MM-DD)"
    string :to_date, required: false, description: "optional inclusive ISO date filter (YYYY-MM-DD)"
  end

  def initialize(workspace)
    @workspace = workspace
  end

  def execute(limit: nil, from_date: nil, to_date: nil)
    dates = parse_dates(from_date, to_date)
    return { error: dates[:error] } if dates[:error]

    requested_limit = limit.to_i
    requested_limit = 10 unless requested_limit.positive?

    entries = ledger.journal_entries
      .includes(:reversal, journal_entry_lines: :account)
      .order(effective_date: :desc, id: :desc)
      .limit([ requested_limit, 20 ].min)

    entries = entries.where(effective_date: dates[:from]..) if dates[:from]
    entries = entries.where(effective_date: ..dates[:to]) if dates[:to]

    entries.map do |entry|
      {
        id: entry.id,
        number: entry.number,
        date: entry.effective_date.iso8601,
        description: entry.description,
        source: entry.source_type,
        reverses_journal_entry_id: entry.reverses_entry_id,
        reversed: entry.reversal.present?,
        lines: entry.journal_entry_lines.map do |line|
          {
            account: line.account.name,
            debit_naira: format_amount(line.debit),
            credit_naira: format_amount(line.credit)
          }
        end
      }
    end
  end

  private

  def parse_dates(from_date, to_date)
    from = Date.iso8601(from_date) if from_date.present?
    to = Date.iso8601(to_date) if to_date.present?
    return { error: "from_date cannot be after to_date" } if from && to && from > to

    { from: from, to: to }
  rescue ArgumentError
    { error: "dates must use ISO format YYYY-MM-DD" }
  end

  def format_amount(kobo)
    format("%.2f", BigDecimal(kobo) / 100)
  end

  def ledger
    @ledger ||= @workspace.ledger
  end
end
