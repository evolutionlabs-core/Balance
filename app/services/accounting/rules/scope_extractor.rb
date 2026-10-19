class Accounting::Rules::ScopeExtractor
  def self.call(command)
    {
      ledger_id: command.ledger&.id,
      source_type: command.source_type,
      action: command.action
    }
  end
end
