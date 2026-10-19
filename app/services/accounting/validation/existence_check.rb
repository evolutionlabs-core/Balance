module Accounting::Validation
  module ExistenceCheck
    def self.call(command)
      [].tap do |errors|
        errors << error(:existence, "Ledger is not persisted") unless command.ledger.persisted?

        command.lines.each_with_index do |line, index|
          account = line.account
          if !account.persisted?
            errors << error(:existence, "Line #{index + 1}: account #{account.name} is not persisted")
          elsif account.ledger_id != command.ledger.id
            errors << error(:existence, "Line #{index + 1}: account #{account.name} belongs to another ledger")
          end
        end
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
