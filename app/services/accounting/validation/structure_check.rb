module Accounting::Validation
  module StructureCheck
    def self.call(command)
      [].tap do |errors|
        errors << error(:structure, "missing ledger") unless command.ledger.is_a?(Ledger)
        errors << error(:structure, "missing effective date") unless command.effective_date.is_a?(Date)
        errors << error(:structure, "An entry requires at least two lines") unless command.lines.is_a?(Array) && command.lines.size >= 2

        Array(command.lines).each_with_index do |line, index|
          account = line.respond_to?(:account) ? line.account : nil
          errors << error(:structure, "Line #{index + 1}: account must be an account") unless account.is_a?(Account)
          errors << error(:structure, "Line #{index + 1}: amounts must be whole kobo") unless kobo_amounts?(line)
        end
      end
    end

    class << self
      private
        def kobo_amounts?(line)
          line.respond_to?(:debit) && line.respond_to?(:credit) &&
            line.debit.is_a?(Integer) && line.credit.is_a?(Integer)
        end

        def error(check, message)
          Error.new(check, message)
        end
    end
  end
end
