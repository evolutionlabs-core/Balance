module Engine::Validation
  module Normalizer
    def self.call(command)
      NormalizedCommand.new(
        ledger: command.ledger,
        effective_date: command.effective_date,
        source_type: command.source_type,
        source_id: command.source_id,
        action: command.action,
        metadata: command.metadata,
        lines: command.lines.map do |line|
          Engine::Command::Line.new(
            ledger_account: line.ledger_account,
            debit: line.debit.to_d,
            credit: line.credit.to_d
          )
        end
      )
    end
  end
end
