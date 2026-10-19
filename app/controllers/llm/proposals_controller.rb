class Llm::ProposalsController < Llm::ProposalActionsController
  def update
    return respond_with_card unless @proposal.entry_proposal?
    return respond_with_card unless @proposal.pending?
    return respond_with_card if @proposal.reversal_proposal?

    return respond_with_card(draft.errors) if draft.invalid?

    @proposal.update!(data: draft.data)
    respond_with_card
  end

  private
    def proposal_params
      params.expect(proposal: [ :description, :effective_date, :reverses_journal_entry_id, lines: [ [ :account_id, :side, :amount_naira ] ] ])
    end

    def draft
      @draft ||= if @proposal.reversal_proposal?
        Llm::EntryProposal.new(workspace: current_workspace, data: @proposal.data)
      else
        Llm::EntryProposal.from_form(workspace: current_workspace, params: proposal_params)
      end
    end
end
