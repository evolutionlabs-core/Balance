class AccountingEngine::Balances
  DIFFERENCE = "journal_entry_lines.debit - journal_entry_lines.credit".freeze

  def initialize(ledger)
    @ledger = ledger
  end

  def by_account(dates = nil)
    sums(lines(dates).group(:account_id))
  end

  def by_counterparty(counterparty, subtype:, dates: nil)
    sums(lines(dates).joins(:account).where(accounts: { subtype: subtype }).group("journal_entry_lines.#{counterparty}_id"))
  end

  def by_date_and_account(dates)
    sums(lines(dates).group("journal_entries.effective_date", :account_id))
  end

  def activity(account, dates)
    lines(dates).where(account: account)
      .includes(:journal_entry, :customer, :vendor)
      .order("journal_entries.effective_date", "journal_entries.number", :id)
  end

  private
    attr_reader :ledger

    def lines(dates)
      scope = JournalEntryLine.joins(:journal_entry).where(journal_entries: { ledger_id: ledger.id })
      dates ? scope.where(journal_entries: { effective_date: dates }) : scope
    end

    def sums(grouped)
      grouped.sum(DIFFERENCE).transform_values(&:to_i)
    end
end
