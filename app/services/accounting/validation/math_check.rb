module Accounting::Validation
  module MathCheck
    def self.call(command)
      debits = command.lines.sum(&:debit)
      credits = command.lines.sum(&:credit)

      if debits == credits
        []
      else
        [ error(:match, "Total debits (#{naira(debits)}) must equal total credits (#{naira(credits)})") ]
      end
    end

    class << self
      private
        def naira(kobo)
          format("%.2f", BigDecimal(kobo) / 100)
        end

        def error(check, message)
          Error.new(check, message)
        end
    end
  end
end
