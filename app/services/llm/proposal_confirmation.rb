class Llm::ProposalConfirmation
  attr_reader :errors, :generated_proposal, :superseded_proposals, :resumed_turn

  def initialize(proposal:, workspace:, attributes:)
    @proposal = proposal
    @workspace = workspace
    @attributes = attributes
  end

  def confirm
    @errors = if @proposal.reversal_confirmation?
      confirm_reversal
    elsif @proposal.account_creation_proposal?
      @proposal.confirm_accounts!(draft: account_draft)
    else
      @proposal.confirm!(draft: entry_draft)
    end

    resume_after_account_creation if @errors.nil? && @proposal.reload.account_creation_proposal? && @proposal.confirmed?
    self
  rescue ActiveRecord::RecordInvalid => error
    @errors = [ error.message ]
    self
  end

  private
    def confirm_reversal
      confirmation = Llm::ReversalConfirmation.new(@proposal).confirm
      @generated_proposal = confirmation.proposal
      @superseded_proposals = confirmation.superseded
      confirmation.errors
    end

    def entry_draft
      if @proposal.reversal_proposal?
        Llm::EntryProposal.new(workspace: @workspace, data: @proposal.data)
      else
        Llm::EntryProposal.from_form(workspace: @workspace, params: @attributes)
      end
    end

    def account_draft
      Llm::AccountCreationProposal.new(workspace: @workspace, data: @proposal.data)
    end

    def resume_after_account_creation
      return unless @proposal.llm_message&.response_turn

      created = @proposal.data.fetch("created_accounts").map { |account| "#{account.fetch("name")} (id #{account.fetch("id")})" }.join(", ")
      message = @proposal.llm_chat.resume_turn(
        "The user approved the account proposal. Created #{created}. Continue the pending transaction using these account IDs without asking for approval again."
      )
      @resumed_turn = message.llm_turn
    end
end
