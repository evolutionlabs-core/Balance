module AccountingEngine
  def self.post(command)
    Posting.call(command)
  end

  def self.record(builder, workspace:, attributes:, source_id:, description: nil)
    post(builder.call(workspace: workspace, attributes: attributes, source_id: source_id, description: description))
  rescue Builders::AccountMissing => error
    Receipt.rejected([ Error.new(:account_missing, error.message) ])
  end

  def self.reverse(entry, on:, source_type:, source_id:, action: "reverse", description: nil)
    record(
      Builders::Reversal,
      workspace: entry.ledger.workspace,
      attributes: { source_type: source_type, action: action, effective_date: on, entry: entry },
      source_id: source_id,
      description: description
    )
  end
end
