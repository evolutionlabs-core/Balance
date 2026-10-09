class Engine::Query < Data.define(:ledger, :as_of, :account_ids)
  def initialize(ledger:, as_of: Date.current, account_ids: nil)
    super(ledger:, as_of:, account_ids: account_ids&.freeze)
  end
end
