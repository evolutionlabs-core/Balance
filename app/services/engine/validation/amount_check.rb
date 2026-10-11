module Engine::Validation
  module AmountCheck
    def self.call(command)
      invalid = command.lines.reject { |line| one_sided?(line) }
      if invalid.empty?
        []
      else
        [ error(:amount, "Each line must have either a positive debit or a positive credit") ]
      end
    end

    class << self
      private
        def one_sided?(line)
          debit = line.debit.to_d
          credit = line.credit.to_d

          (debit.positive? && credit.zero?) || (credit.positive? && debit.zero?)
        end

        def error(check, message)
          Error.new(check, message)
        end
    end
  end
end
