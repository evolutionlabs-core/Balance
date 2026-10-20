require "test_helper"

class Llm::ToolOutputPrunerTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      model: ruby_llm_models(:default),
      title: "Pruner test"
    )
  end

  def tool_message(content)
    @chat.llm_messages.create!(role: "tool", content: content)
  end

  test "keeps the newest tool outputs under the protect budget and marks the rest" do
    stub_const(Llm::Chat, :PRUNE_PROTECT_TOKENS, 300) do
      messages = 5.times.map { tool_message("x" * 1_000) }

      Llm::ToolOutputPruner.new(@chat).call

      assert_nil messages.last.reload.summarized_at
      assert messages.first(4).all? { |message| message.reload.summarized_at.present? }
    end
  end

  test "leaves tool outputs alone when they fit the protect budget" do
    stub_const(Llm::Chat, :PRUNE_PROTECT_TOKENS, 300) do
      messages = 2.times.map { tool_message("x" * 100) }

      Llm::ToolOutputPruner.new(@chat).call

      assert messages.all? { |message| message.reload.summarized_at.nil? }
    end
  end

  test "is idempotent" do
    stub_const(Llm::Chat, :PRUNE_PROTECT_TOKENS, 300) do
      5.times.map { tool_message("x" * 1_000) }

      Llm::ToolOutputPruner.new(@chat).call
      first_run = @chat.llm_messages.where.not(summarized_at: nil).count
      Llm::ToolOutputPruner.new(@chat).call

      assert_equal first_run, @chat.llm_messages.where.not(summarized_at: nil).count
    end
  end
end
