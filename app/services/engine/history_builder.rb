class Engine::HistoryBuilder
  def self.call(query)
    new(query).call
  end

  def initialize(query)
    @query = query
  end

  def call
    if query.account_ids
      scoped.order(:effective_date, :id)
    else
      all.order(:effective_date, :id)
    end
  end

  private
    attr_reader :query

    def all
      query.ledger.ledger_entries
        .includes(ledger_lines: :ledger_account)
        .where(effective_date: ..query.as_of)
    end

    def scoped
      all.where(id: LedgerLine.where(ledger_account_id: query.account_ids).select(:ledger_entry_id))
    end
end
