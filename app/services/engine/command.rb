class Engine::Command < Data.define(:ledger, :effective_date, :lines, :source_type, :source_id, :action)
  Line = Data.define(:ledger_account, :debit, :credit)

  def initialize(ledger:, effective_date:, lines:, source_type: nil, source_id: nil, action: nil)
    super(ledger:, effective_date:, lines: lines.freeze, source_type:, source_id:, action:)
  end
end
