class Llm::ReversalConfirmation
  attr_reader :errors, :proposal, :superseded

  def self.entry_data(entry, use_original_date: false)
    {
      "source_ledger_entry_id" => entry.id,
      "description" => entry.description,
      "effective_date" => entry.effective_date.iso8601,
      "use_original_date" => use_original_date,
      "lines" => entry.ledger_lines.map do |line|
        {
          "ledger_account_id" => line.ledger_account_id,
          "account_name" => line.ledger_account.name,
          "side" => line.debit.positive? ? "debit" : "credit",
          "amount_kobo" => line.debit.positive? ? line.debit : line.credit
        }
      end
    }
  end

  def initialize(confirmation)
    @confirmation = confirmation
    @chat = confirmation.llm_chat
    @errors = []
    @superseded = []
  end

  def confirm
    @chat.with_lock do
      @confirmation.lock!
      return self unless @confirmation.reversal_confirmation?

      if @confirmation.confirmed?
        @proposal = @chat.proposals.find(@confirmation.data.fetch("reversal_proposal_id"))
        return self
      end
      return self unless @confirmation.pending?

      entry = ledger.ledger_entries.includes(:ledger_lines).find_by(id: @confirmation.data.fetch("source_ledger_entry_id"))
      unless entry
        @errors = [ "That entry does not exist in this workspace." ]
        return self
      end

      draft = Llm::EntryProposal.new(workspace: @chat.workspace, data: reversal_data(entry))
      if draft.invalid?
        @errors = draft.errors
        return self
      end

      @superseded = @chat.proposals.proposed.by_type("entry").to_a
      @superseded.each(&:supersede!)
      @proposal = @chat.proposals.create!(
        workspace: @chat.workspace,
        proposal_type: "entry",
        version: (@chat.proposals.by_type("entry").maximum(:version) || 0) + 1,
        data: draft.data
      )
      @confirmation.update!(
        status: "confirmed",
        data: @confirmation.data.merge("reversal_proposal_id" => @proposal.id)
      )
    end
    self
  end

  private

  def reversal_data(entry)
    {
      "description" => "Reversal of entry ##{entry.id}: #{entry.description}",
      "effective_date" => (@confirmation.data["use_original_date"] ? entry.effective_date : Date.current).iso8601,
      "amount_source" => "existing_posted_entry",
      "reverses_ledger_entry_id" => entry.id,
      "lines" => entry.ledger_lines.map do |line|
        {
          "source_line_id" => line.id,
          "ledger_account_id" => line.ledger_account_id,
          "side" => line.credit.positive? ? "debit" : "credit",
          "amount_kobo" => line.credit.positive? ? line.credit : line.debit
        }
      end
    }
  end

  def ledger
    @chat.workspace.ledgers.first || @chat.workspace.provision_ledger!(template: @chat.workspace.ledger_template)
  end
end
