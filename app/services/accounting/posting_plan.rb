class Accounting::PostingPlan < Data.define(:workspace_id, :entry_date, :description, :lines)
  Line = Data.define(:account_id, :debit_kobo, :credit_kobo, :counterparty_type, :counterparty_id) do
    def initialize(account_id:, debit_kobo:, credit_kobo:, counterparty_type: nil, counterparty_id: nil)
      super
    end
  end

  def initialize(workspace_id:, entry_date:, description:, lines:)
    super(workspace_id:, entry_date:, description:, lines: lines.freeze)
  end
end
