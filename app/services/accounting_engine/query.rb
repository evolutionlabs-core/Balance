module AccountingEngine
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
        statement_result(
          FinancialStatements.balance_sheet(
            ledger: Ledger.find(ledger_id),
            dates: options[:dates] || [ [ as_of_date.strftime("%b %-d, %Y"), as_of_date ] ]
          )
        )
      when "income_statement"
        start_date = options[:start_date] || as_of_date.beginning_of_month
        end_date = options[:end_date] || as_of_date
        statement_result(
          FinancialStatements.income_statement(
            ledger: Ledger.find(ledger_id),
            periods: options[:periods] || [ [ "#{start_date.strftime("%b %-d")} – #{end_date.strftime("%b %-d, %Y")}", start_date, end_date ] ]
          )
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
          workspace_type: options[:workspace_type] || "business"
        )
      else
        raise ArgumentError, "Unknown query_type: #{query_type}"
      end

      ResponseShaper.call(result)
    end

    def self.statement_result(statement)
      Result.new(data: statement, metadata: { columns: statement.columns.map(&:label) }, errors: [])
    end
    private_class_method :statement_result
  end
end
