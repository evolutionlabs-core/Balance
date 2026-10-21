module AccountingEngine
  module Builders
    class OpeningBalance < Base
      ELIGIBLE_SUBTYPES = %w[cash inventory fixed_asset accumulated_depreciation investment other_asset credit_card tax_payable loan other_liability].freeze

      private
        def effective_date
          attributes.fetch(:effective_date, Date.current)
        end

        def action
          "create"
        end

        def description
          "Opening balance"
        end

        def lines
          account_lines = balances.map do |key, amount|
            account = account_for(key)
            raise AccountMissing, "#{account.name} can't take an opening balance." unless ELIGIBLE_SUBTYPES.include?(account.subtype)

            if account.normal_balance == "debit"
              AccountingEngine::Command::Line.new(account: account, debit: amount, credit: 0)
            else
              AccountingEngine::Command::Line.new(account: account, debit: 0, credit: amount)
            end
          end

          net = account_lines.sum(&:debit) - account_lines.sum(&:credit)
          net.zero? ? account_lines : account_lines + [ equity_line(net) ]
        end

        def equity_line(net)
          equity = account_for("opening_balance_equity")

          if net.positive?
            AccountingEngine::Command::Line.new(account: equity, debit: 0, credit: net)
          else
            AccountingEngine::Command::Line.new(account: equity, debit: -net, credit: 0)
          end
        end

        def balances
          attributes.fetch(:balances).select { |_key, amount| amount.positive? }
        end
    end
  end
end
