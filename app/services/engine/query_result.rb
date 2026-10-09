class Engine::QueryResult < Data.define(:ledger, :as_of, :balances, :entries, :trial_balance)
end
