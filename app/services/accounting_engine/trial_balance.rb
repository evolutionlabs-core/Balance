class AccountingEngine::TrialBalance
  Row = Data.define(:account, :debit, :credit)

  attr_reader :as_of

  def initialize(ledger, as_of: Date.current)
    @ledger = ledger
    @as_of = as_of
  end

  def rows
    @rows ||= begin
      raw = AccountingEngine::Balances.new(ledger).by_account(..as_of)

      ledger.accounts.order(:code).filter_map do |account|
        balance = raw.fetch(account.id, 0)
        Row.new(account: account, debit: [ balance, 0 ].max, credit: [ -balance, 0 ].max) unless balance.zero?
      end
    end
  end

  def total_debit
    rows.sum(&:debit)
  end

  def total_credit
    rows.sum(&:credit)
  end

  def balanced?
    total_debit == total_credit
  end

  private
    attr_reader :ledger
end
