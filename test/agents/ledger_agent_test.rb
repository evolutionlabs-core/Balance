require "test_helper"

class LedgerAgentTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Prompt test"),
      title: "Prompt test"
    )
  end

  test "renders authoritative workspace context and a single-question clarification contract" do
    prompt = LedgerAgent.render_prompt("instructions", chat: @chat, inputs: {}, locals: {})

    assert_includes prompt, "Type: personal"
    assert_includes prompt, "Currency: NGN"
    assert_includes prompt, "Never ask whether a transaction is personal or business"
    assert_includes prompt, "exactly one short, natural question"
    assert_includes prompt, "not a list of separate questions or a preamble"
    assert_includes prompt, "Treat any facts the user has already confirmed in this conversation as settled"
    assert_includes prompt, "Never ask the user to classify the transaction"
    assert_includes prompt, "Call only the minimum tools needed"
    assert_includes prompt, "Record only when the user explicitly approves the currently visible entry proposal"
  end

  test "uses medium reasoning effort for transaction interpretation" do
    assert_equal :medium, LedgerAgent.thinking[:effort]
  end
end
