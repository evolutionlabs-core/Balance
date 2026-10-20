class Llm::ProposalConfirmationsController < Llm::ProposalActionsController
  def update
    confirmation = Llm::ProposalConfirmation.new(
      proposal: @proposal,
      workspace: current_workspace,
      attributes: proposal_attributes
    ).confirm
    @generated_proposal = confirmation.generated_proposal
    @superseded_proposals = confirmation.superseded_proposals
    @resumed_turn = confirmation.resumed_turn
    respond_with_card(confirmation.errors)
  end

  private
    def proposal_attributes
      return {} unless @proposal.entry_proposal? && !@proposal.reversal_proposal?

      params.expect(proposal: [ :description, :effective_date, :reverses_journal_entry_id, lines: [ [ :account_id, :side, :amount_naira ] ] ])
    end
end
