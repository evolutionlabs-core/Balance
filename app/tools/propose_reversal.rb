class ProposeReversal < RubyLLM::Tool
  description "Show an entry-bound confirmation card for a recorded entry selected for reversal. " \
              "Call as soon as the target entry is known; do not ask a separate text confirmation. " \
              "The user confirms the exact entry on the card, then reviews a separate immutable reversal proposal. " \
              "This tool never records or changes an entry."

  params do
    integer :entry_id, description: "recorded entry ID returned by list_journal_entries"
    boolean :use_original_date, required: false,
                                description: "true only when the user explicitly requests the original entry date"
  end

  def initialize(chat)
    @workspace = chat.workspace
  end

  def execute(entry_id:, use_original_date: false)
    entry = ledger.ledger_entries.includes(:ledger_lines).find_by(id: entry_id)
    return { error: "That entry does not exist in this workspace." } unless entry
    return { error: "That entry has already been reversed." } if reversed?(entry.id)
    return { error: "That entry is itself a reversal." } if reversal_entry?(entry.id)

    halt({
      proposal: true,
      proposed_action: "reversal_confirmation",
      entry_data: Llm::ReversalConfirmation.entry_data(entry, use_original_date: use_original_date),
      message: "Confirm the selected entry on the card. Nothing has been reversed or recorded."
    })
  end

  private

  def reversed?(entry_id)
    confirmed_reversals.where("data ->> 'reverses_ledger_entry_id' = ?", entry_id.to_s).exists?
  end

  def reversal_entry?(entry_id)
    confirmed_reversals.where("data -> 'reverses_ledger_entry_id' IS NOT NULL")
      .find_by(ledger_entry_id: entry_id).present?
  end

  def confirmed_reversals
    Proposal.where(proposal_type: "entry", status: "confirmed")
  end

  def ledger
    @ledger ||= @workspace.ledgers.first ||
      @workspace.provision_ledger!(template: @workspace.ledger_template)
  end
end
