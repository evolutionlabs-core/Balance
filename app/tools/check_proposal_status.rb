class CheckProposalStatus < RubyLLM::Tool
  description "Report the status of the most recent entry proposals in this workspace so you can say whether a proposed entry has been recorded. A confirmed proposal is a recorded journal entry; a proposed one is still waiting for approval."

  def initialize(workspace)
    @workspace = workspace
  end

  def execute
    proposals = @workspace.proposals
      .includes(:journal_entry)
      .where(proposal_type: "entry")
      .order(created_at: :desc, id: :desc)
      .limit(10)

    proposals.map do |proposal|
      entry = proposal.journal_entry
      {
        id: proposal.id,
        description: proposal.data&.dig("description"),
        effective_date: proposal.data&.dig("effective_date"),
        amount_naira: format_amount(proposal.total_debit_kobo),
        status: proposal.status,
        recorded_as_entry_id: entry&.id,
        recorded_on: entry&.effective_date&.iso8601
      }
    end
  end

  private

  def format_amount(kobo)
    format("%.2f", BigDecimal(kobo.to_i) / 100)
  end
end
