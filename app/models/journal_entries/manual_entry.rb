module JournalEntries
  class ManualEntry
    include ActiveModel::Model

    validates :description, :effective_date, presence: true
    validate :effective_date_is_parseable
    validate :entry_lines_are_valid

    attr_accessor :workspace, :effective_date, :description

    def lines
      @lines ||= []
    end

    def lines=(raw)
      raw_rows = raw.is_a?(Hash) ? raw.values : Array(raw)
      @lines = raw_rows.reject { |line| line.to_h.stringify_keys["_destroy"] == "1" }
        .map { |line| Line.new(**line.to_h.symbolize_keys) }
    end

    def build_line
      lines << Line.new
    end

    def record!
      return false unless valid?

      receipt = Accounting.post(
        Accounting::Adapters::Entry.call(
          workspace: workspace,
          attributes: { effective_date: parsed_date, lines: active_lines.map(&:command_line) },
          source_id: nil,
          description: description
        )
      )

      return true if receipt.success?

      receipt.errors.each { |error| errors.add(:base, error.to_s) }
      false
    end

    private
      def effective_date_is_parseable
        return if effective_date.blank? || parsed_date

        errors.add(:effective_date, "is not a valid date")
      end

      def entry_lines_are_valid
        posted = active_lines
        errors.add(:base, "An entry requires at least two lines") if posted.size < 2

        posted.each_with_index do |line, index|
          number = index + 1

          unless workspace.accounts.exists?(line.account_id.to_i)
            errors.add(:base, "Line #{number}: choose an account in this workspace")
          end

          if line.debit_kobo.positive? && line.credit_kobo.positive?
            errors.add(:base, "Line #{number}: enter a debit or a credit, not both")
          elsif line.debit_kobo.zero? && line.credit_kobo.zero?
            errors.add(:base, "Line #{number}: enter a debit or a credit")
          end
        end
      end

      def active_lines
        lines.reject(&:blank_row?)
      end

      def parsed_date
        effective_date.is_a?(Date) ? effective_date : Date.iso8601(effective_date.to_s)
      rescue Date::Error
        nil
      end

      class Line
        include ActiveModel::Model

        attr_accessor :account_id, :debit, :credit, :_destroy

        def blank_row?
          account_id.blank? && debit_kobo.zero? && credit_kobo.zero?
        end

        def command_line
          { account_id: account_id.to_i, debit: debit_kobo, credit: credit_kobo }
        end

        def debit_kobo
          kobo(debit)
        end

        def credit_kobo
          kobo(credit)
        end

        private
          def kobo(naira)
            raw = naira.to_s.gsub(/[^\d.]/, "")
            return 0 if raw.blank?

            (BigDecimal(raw) * 100).round
          end
      end
  end
end
