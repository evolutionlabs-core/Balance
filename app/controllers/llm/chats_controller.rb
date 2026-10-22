class Llm::ChatsController < ApplicationController
  before_action :set_llm_chat, only: [ :show, :destroy ]

  def index
    @llm_chats = current_workspace.llm_chats.order(updated_at: :desc)
    @chat_models = available_chat_models
    @selected_model = params[:model]
  end

  def create
    prompt = params.dig(:llm_chat, :prompt)

    if prompt.blank?
      @llm_chats = current_workspace.llm_chats.order(updated_at: :desc)
      @chat_models = available_chat_models
      @selected_model = params.dig(:llm_chat, :model)
      @prompt = prompt
      flash.now[:alert] = "Type a message to start a chat."
      return render :index, status: :unprocessable_content
    end

    @llm_chat = current_workspace.llm_chats.new(model: params.dig(:llm_chat, :model).presence)
    @llm_chat.derive_title_from(prompt)
    @llm_chat.save!
    @llm_chat.start_turn(prompt)

    redirect_to chat_path(@llm_chat)
  end

  def show
    @llm_message = @llm_chat.llm_messages.build
  end

  def destroy
    @llm_chat.destroy!
    redirect_to chats_path, notice: "Chat deleted.", status: :see_other
  end

  private

  def set_llm_chat
    @llm_chat = current_workspace.llm_chats.find_by!(uuid: params[:uuid])
  end
end
