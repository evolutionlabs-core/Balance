class Engine::Command < Data.define(:ledger, :effective_date, :lines, :source_type, :source_id, :action, :reverses_ledger_entry, :metadata)
  Line = Data.define(:ledger_account, :debit, :credit)

  def initialize(ledger:, effective_date:, lines:, source_type: nil, source_id: nil, action: nil, reverses_ledger_entry: nil, metadata: {})
    super(ledger:, effective_date:, lines: lines.freeze, source_type:, source_id:, action:, reverses_ledger_entry:, metadata: metadata.deep_stringify_keys.freeze)
  end
end
