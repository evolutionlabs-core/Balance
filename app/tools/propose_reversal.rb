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
    entry = ledger.journal_entries.includes(:journal_entry_lines).find_by(id: entry_id)
    return { error: "That entry does not exist in this workspace." } unless entry
    return { error: "That entry has already been reversed." } if entry.reversed?
    return { error: "That entry is itself a reversal." } if entry.reverses_entry_id?

    halt({
      proposal: true,
      proposed_action: "reversal_confirmation",
      entry_data: Llm::ReversalConfirmation.entry_data(entry, use_original_date: use_original_date),
      message: "Confirm the selected entry on the card. Nothing has been reversed or recorded."
    })
  end

  private

  def ledger
    @workspace.ledger
  end
end
