class Llm::ProposalActionsController < ApplicationController
  before_action :set_llm_chat
  before_action :set_proposal

  private
    def set_llm_chat
      @llm_chat = current_workspace.llm_chats.find_by!(uuid: params[:chat_uuid])
    end

    def set_proposal
      @proposal = @llm_chat.proposals.find(params[:proposal_id] || params[:id])
    end

    def respond_with_card(errors = nil)
      partial = Llm::MessagesHelper::PROPOSAL_PARTIALS.fetch(@proposal.proposal_type)

      respond_to do |format|
        format.turbo_stream do
          streams = [ turbo_stream.replace(
            "proposal_#{@proposal.id}", partial: partial,
            locals: { proposal: @proposal, errors: errors }
          ) ]
          Array(@superseded_proposals).each { |proposal| streams << turbo_stream.remove("proposal_#{proposal.id}") }
          if @generated_proposal
            streams << turbo_stream.append(
              "llm_messages", partial: "llm/messages/proposals/entry",
              locals: { proposal: @generated_proposal }
            )
          end
          if @resumed_turn
            streams << turbo_stream.append(
              "llm_messages", partial: "llm/messages/turn_status",
              locals: { turn: @resumed_turn }
            )
          end
          render turbo_stream: streams
        end
        format.html { redirect_to chat_path(@llm_chat) }
      end
    end
end
