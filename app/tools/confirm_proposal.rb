class ConfirmProposal < RubyLLM::Tool
  description "Record the current reviewable entry proposal after the user explicitly approves it. " \
              "Use only for a direct instruction such as 'record it' or 'approve this entry'. " \
              "This is idempotent and never confirms an account-creation proposal."

  def initialize(chat)
    @chat = chat
  end

  def execute
    if @chat.proposals.proposed.by_type("reversal_confirmation").exists?
      return { error: "Confirm the selected entry on its reversal confirmation card. Nothing has been recorded." }
    end

    proposal = current_proposal
    unless proposal
      recorded = last_recorded_proposal
      return recorded_result(recorded, already_recorded: true) if recorded

      return { error: "There is no entry proposal awaiting approval." }
    end

    if proposal.reversal_proposal?
      return { error: "Reversal proposals cannot be recorded through chat. Review and approve the proposal explicitly." }
    end

    unless explicitly_approved?(proposal)
      return { error: "The current entry proposal has not been explicitly approved by the user." }
    end

    draft = Llm::EntryProposal.new(workspace: @chat.workspace, data: proposal.data)
    errors = proposal.confirm!(draft: draft)
    return { error: errors.join(", ") } if errors.present?

    proposal.reload
    Llm::ChatBroadcaster.new(@chat).proposal_updated(proposal)

    recorded_result(proposal)
  rescue ActiveRecord::RecordInvalid => error
    { error: error.record.errors.full_messages.join(", ") }
  end

  private

  def explicitly_approved?(proposal)
    user_message = @chat.llm_messages.where(role: "user").order(:id).last
    return false unless Llm::ExplicitApproval.call(user_message&.content)

    proposal.created_at <= user_message.created_at
  end

  def recorded_result(proposal, already_recorded: false)
    {
      message: "Entry recorded.",
      proposal_id: proposal.id,
      status: proposal.status,
      ledger_entry_id: proposal.ledger_entry_id,
      description: proposal.description,
      effective_date: proposal.effective_date,
      already_recorded: already_recorded
    }
  end

  def current_proposal
    @chat.proposals.proposed.by_type("entry").order(version: :desc, id: :desc).first
  end

  def last_recorded_proposal
    @chat.proposals.by_type("entry").where(status: "confirmed").order(version: :desc, id: :desc).first
  end
end
