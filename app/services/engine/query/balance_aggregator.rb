module Engine
  module Query
    class BalanceAggregator
      def self.call(ledger_id:, as_of_date: nil, start_date: nil, end_date: nil)
        new(ledger_id: ledger_id, as_of_date: as_of_date, start_date: start_date, end_date: end_date).call
      end

      def initialize(ledger_id:, as_of_date: nil, start_date: nil, end_date: nil)
        @ledger_id = ledger_id
        @as_of_date = as_of_date
        @start_date = start_date
        @end_date = end_date
      end

      def call
        rows = chart_accounts.map do |account|
          raw_debit, raw_credit = sums.fetch(account.id, [ 0, 0 ])
          {
            account_id: account.id,
            code: account.code,
            name: account.name,
            base_type: account.base_type,
            subtype: account.subtype,
            normal_balance: account.normal_balance,
            raw_debit: raw_debit,
            raw_credit: raw_credit,
            balance: raw_debit - raw_credit
          }
        end

        Result.new(data: { accounts: rows }, metadata: query_metadata, errors: [])
      end

      private
        attr_reader :ledger_id, :as_of_date, :start_date, :end_date

        def chart_accounts
          LedgerAccount.where(ledger_id: ledger_id).ordered
        end

        def sums
          @sums ||= line_scope.group(:ledger_account_id)
            .pluck(:ledger_account_id, Arel.sql("SUM(ledger_lines.debit)"), Arel.sql("SUM(ledger_lines.credit)"))
            .to_h { |account_id, debit, credit| [ account_id, [ debit.to_i, credit.to_i ] ] }
        end

        def line_scope
          scope = LedgerLine.joins(:ledger_entry).where(ledger_entries: { ledger_id: ledger_id })
          date_range ? scope.where(ledger_entries: { effective_date: date_range }) : scope
        end

        def date_range
          if start_date && end_date
            start_date..end_date
          elsif start_date
            start_date..
          elsif end_date
            ..end_date
          elsif as_of_date
            ..as_of_date
          end
        end

        def query_metadata
          { as_of_date: as_of_date, start_date: start_date, end_date: end_date }.compact
        end
    end
  end
end
