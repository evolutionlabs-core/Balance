module Engine::Validation
  module MathCheck
    def self.call(command)
      debits = command.lines.sum { |line| line.debit.to_d }
      credits = command.lines.sum { |line| line.credit.to_d }

      if debits == credits
        []
      else
        [ error(:match, "Total debits (#{debits}) must equal total credits (#{credits})") ]
      end
    end

    class << self
      private
        def error(check, message)
          Error.new(check, message)
        end
    end
  end
end
