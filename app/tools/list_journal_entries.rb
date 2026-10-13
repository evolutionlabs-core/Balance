class ListJournalEntries < RubyLLM::Tool
  description "List recorded ledger entries in this workspace. Entries the assistant recorded from chat have source \"Entry\". " \
              "A confirmed reversal proposal carries the source entry under reverses_ledger_entry_id, which is present only when the entry is itself a reversal."

  params do
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

    entries = ledger.ledger_entries
      .includes(ledger_lines: :ledger_account)
      .order(effective_date: :desc, id: :desc)
      .limit([ requested_limit, 20 ].min)

    entries = entries.where(effective_date: dates[:from]..) if dates[:from]
    entries = entries.where(effective_date: ..dates[:to]) if dates[:to]

    reversals_by_entry = Proposal.where(proposal_type: "entry", status: "confirmed")
      .where("data -> 'reverses_ledger_entry_id' IS NOT NULL")
      .index_by(&:ledger_entry_id)

    entries.map do |entry|
      {
        id: entry.id,
        date: entry.effective_date.iso8601,
        description: entry.description,
        source: entry.source_type,
        reverses_ledger_entry_id: reversals_by_entry[entry.id]&.data&.dig("reverses_ledger_entry_id"),
        lines: entry.ledger_lines.map do |line|
          {
            account: line.ledger_account.name,
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
    @ledger ||= @workspace.ledgers.first ||
      @workspace.provision_ledger!(template: @workspace.ledger_template)
  end
end
