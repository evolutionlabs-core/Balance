class Engine::Command < Data.define(:ledger, :effective_date, :lines, :source_type, :source_id, :action, :description, :metadata)
  Line = Data.define(:ledger_account, :debit, :credit)

  def initialize(ledger:, effective_date:, lines:, source_type: nil, source_id: nil, action: nil, description: nil, metadata: {})
    super(ledger:, effective_date:, lines: lines.freeze, source_type:, source_id:, action:, description:, metadata: metadata.deep_stringify_keys.freeze)
  end
end
