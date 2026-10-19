module Accounting
  module Query
    class HistoryBuilder
      def self.call(ledger_id:, account_id: nil, page: 1, per_page: 50)
        new(ledger_id: ledger_id, account_id: account_id, page: page, per_page: per_page).call
      end

      def initialize(ledger_id:, account_id: nil, page: 1, per_page: 50)
        @ledger_id = ledger_id
        @account_id = account_id
        @page = [ page.to_i, 1 ].max
        @per_page = per_page.to_i.clamp(1, 100)
      end

      def call
        total_count = scope.count

        Result.new(
          data: {
            entries: page_entries.map { |entry| serialize_entry(entry) },
            pagination: {
              page: page,
              per_page: per_page,
              total_count: total_count,
              total_pages: (total_count / per_page.to_f).ceil
            }
          },
          metadata: {},
          errors: []
        )
      end

      private
        attr_reader :ledger_id, :account_id, :page, :per_page

        def scope
          JournalEntry.where(ledger_id: ledger_id).order(effective_date: :desc, id: :desc)
        end

        def page_entries
          entries = account_id.present? ? scope.where(id: account_entry_ids) : scope
          entries.offset((page - 1) * per_page).limit(per_page).includes(journal_entry_lines: :account).to_a
        end

        def account_entry_ids
          JournalEntryLine.where(account_id: account_id)
            .joins(:journal_entry)
            .where(journal_entries: { ledger_id: ledger_id })
            .select(:journal_entry_id)
        end

        def serialize_entry(entry)
          {
            id: entry.id,
            effective_date: entry.effective_date,
            source_type: entry.source_type,
            source_id: entry.source_id,
            action: entry.action,
            description: entry.description,
            lines: entry.journal_entry_lines.sort_by(&:id).map { |line| serialize_line(line) }
          }
        end

        def serialize_line(line)
          {
            account_id: line.account_id,
            account_name: line.account.name,
            debit: line.debit.to_i,
            credit: line.credit.to_i
          }
        end
    end
  end
end
