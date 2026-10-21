module AccountingEngine::Validation
  module MathCheck
    def self.call(command)
      debits = command.lines.sum(&:debit)
      credits = command.lines.sum(&:credit)

      if debits == credits
        []
      else
        [ error(:match, "Total debits (#{amount(debits)}) must equal total credits (#{amount(credits)})") ]
      end
    end

    class << self
      private
        def amount(kobo)
          format("%.2f", BigDecimal(kobo) / 100)
        end

        def error(check, message)
          AccountingEngine::Error.new(check, message)
        end
    end
  end
end
