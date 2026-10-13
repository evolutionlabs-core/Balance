module Engine
  module Query
    def self.call(ledger_id:, query_type:, as_of_date: Date.current, options: {})
      SnapshotGuard.validate!(ledger_id: ledger_id, as_of_date: as_of_date)

      result = case query_type.to_s
      when "account_balances"
        BalanceAggregator.call(ledger_id: ledger_id, as_of_date: as_of_date)
      when "period_movement"
        BalanceAggregator.call(
          ledger_id: ledger_id,
          start_date: options[:start_date] || as_of_date.beginning_of_month,
          end_date: options[:end_date] || as_of_date
        )
      when "balance_sheet"
        ReportComposer.balance_sheet(ledger_id: ledger_id, as_of_date: as_of_date)
      when "income_statement"
        ReportComposer.income_statement(
          ledger_id: ledger_id,
          start_date: options[:start_date] || as_of_date.beginning_of_month,
          end_date: options[:end_date] || as_of_date
        )
      when "net_worth"
        ReportComposer.net_worth(ledger_id: ledger_id, as_of_date: as_of_date)
      when "cash_position"
        ReportComposer.cash_position(ledger_id: ledger_id, as_of_date: as_of_date)
      when "journal_history"
        HistoryBuilder.call(
          ledger_id: ledger_id,
          account_id: options[:account_id],
          page: options[:page] || 1,
          per_page: options[:per_page] || 50
        )
      when "dashboard"
        ReportComposer.dashboard(
          ledger_id: ledger_id,
          as_of_date: as_of_date,
          workspace_type: options[:workspace_type] || "smb"
        )
      else
        raise ArgumentError, "Unknown query_type: #{query_type}"
      end

      ResponseShaper.call(result)
    end
  end
end
