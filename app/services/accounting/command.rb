class Accounting::Command < Data.define(:ledger, :effective_date, :lines, :source_type, :source_id, :action, :description, :metadata, :reverses_entry, :posted_by)
  # A line on a control account names its counterparty: the customer for
  # receivables, the vendor for payables.
  Line = Data.define(:account, :debit, :credit, :customer, :vendor) do
    def initialize(account:, debit:, credit:, customer: nil, vendor: nil)
      super
    end
  end

  def initialize(ledger:, effective_date:, lines:, source_type: nil, source_id: nil, action: nil, description: nil, metadata: {}, reverses_entry: nil, posted_by: nil)
    super(ledger:, effective_date:, lines: lines.freeze, source_type:, source_id:, action:, description:, metadata: metadata.deep_stringify_keys.freeze, reverses_entry:, posted_by:)
  end
end
