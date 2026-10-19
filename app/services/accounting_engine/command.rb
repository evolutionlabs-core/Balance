class AccountingEngine::Command < Data.define(:ledger, :effective_date, :lines, :source_type, :source_id, :action, :description, :reverses_entry, :posted_by)
  Line = Data.define(:account, :debit, :credit, :customer, :vendor) do
    def initialize(account:, debit:, credit:, customer: nil, vendor: nil)
      super
    end
  end

  def initialize(ledger:, effective_date:, lines:, source_type: nil, source_id: nil, action: nil, description: nil, reverses_entry: nil, posted_by: nil)
    super(ledger:, effective_date:, lines: lines.freeze, source_type:, source_id:, action:, description:, reverses_entry:, posted_by:)
  end
end
