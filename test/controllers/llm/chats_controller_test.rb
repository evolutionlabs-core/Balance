require "test_helper"

class Llm::ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "creates a chat from a prompt" do
    assert_difference "Llm::Chat.count", 1 do
      post chats_path, params: { llm_chat: { prompt: "I sold shoes for 5000 naira cash" } }
    end

    assert_redirected_to chat_path(Llm::Chat.last)
  end

  test "accepts a local model missing from the registry as an OpenAI-compatible model" do
    assert_difference [ "Llm::Chat.count", "RubyLLM::ActiveRecord::Model.count" ], 1 do
      post chats_path, params: { llm_chat: { prompt: "hello there", model: "some-local-model" } }
    end

    assert_redirected_to chat_path(Llm::Chat.last)
    assert_equal "some-local-model", Llm::Chat.last.model.model_id
    assert_equal "openai", Llm::Chat.last.model.provider
  end

  test "renders index with an alert when the prompt is blank" do
    assert_no_difference "Llm::Chat.count" do
      post chats_path, params: { llm_chat: { prompt: "" } }
    end

    assert_response :unprocessable_content
  end

  test "renders the start button disabled until a prompt is entered" do
    get chats_path

    assert_response :success
    assert_select "textarea[data-chat-message-form-target='input']"
    assert_select "button[data-chat-message-form-target='submitButton'][disabled]", text: /Start chat/
  end
end
