require "test_helper"

class Llm::ChatTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      model: ruby_llm_models(:default),
      title: "Compaction test"
    )
  end

  def build_turn(number, weight: 1)
    @chat.llm_messages.create!(role: "user", content: "user #{number}")
    @chat.llm_messages.create!(role: "assistant", content: "assistant #{number}")
    @chat.llm_messages.create!(role: "tool", content: "t" * weight) if weight > 1
  end

  def payload(messages = @chat.llm_messages.to_a)
    @chat.send(:order_messages_for_llm, messages).map(&:content)
  end

  test "orders system messages first and keeps the full dialogue" do
    2.times { |number| build_turn(number + 1) }
    @chat.llm_messages.create!(role: "system", content: "You are Balance.")
    2.times { |number| build_turn(number + 3) }

    result = payload

    assert_equal "You are Balance.", result.first
    assert_equal "user 1", result.second
    assert_includes result, "user 3"
    assert_equal "assistant 4", result.last
  end

  test "marks the active turn as the current request without changing stored content" do
    build_turn(1)
    message = @chat.llm_messages.create!(role: "user", content: "Use separate expense accounts.")
    @chat.active_turn = @chat.llm_turns.create!(user_message: message)

    result = payload

    assert_equal <<~TEXT.chomp, result.last
      [CURRENT EXCHANGE — RESPOND TO THIS]
      User: user 1
      Assistant: assistant 1
      User: Use separate expense accounts.
    TEXT
    assert_equal "Use separate expense accounts.", message.reload.content
  end

  test "skips messages already folded into a summary" do
    3.times { |number| build_turn(number + 1) }
    @chat.llm_messages.where(id: @chat.llm_messages.first(2).map(&:id)).update_all(summarized_at: Time.current)

    result = payload

    refute_includes result, "user 1"
    refute_includes result, "assistant 1"
    assert_includes result, "user 2"
    assert_equal "assistant 3", result.last
  end

  test "needs_compaction? is false for slim history" do
    3.times { |number| build_turn(number + 1) }

    refute @chat.needs_compaction?
  end

  test "needs_compaction? is true once history exceeds 70% of the context window" do
    stub_const(Llm::Chat, :CONTEXT_WINDOW_TOKENS, 4_000) do
      12.times { |number| build_turn(number + 1, weight: 1_000) }

      assert @chat.needs_compaction?
    end
  end

  test "foldable_head is the oldest dialogue beyond the tail budget" do
    stub_const(Llm::Chat, :TAIL_BUDGET_TOKENS, 300) do
      2.times { |number| build_turn(number + 1) }
      2.times { |number| build_turn(number + 3, weight: 1_000) }

      head = @chat.foldable_head.map(&:content)

      assert_equal [ "user 1", "assistant 1", "user 2", "assistant 2", "user 3", "assistant 3", "t" * 1_000 ], head
    end
  end

  test "foldable_head is empty when everything fits the tail budget" do
    stub_const(Llm::Chat, :TAIL_BUDGET_TOKENS, 300) do
      2.times { |number| build_turn(number + 1) }

      assert_empty @chat.foldable_head
    end
  end

  test "current_summary is nil until a compaction summary exists" do
    @chat.llm_messages.create!(role: "system", content: "You are Balance.")

    assert_nil @chat.current_summary
  end

  test "current_summary returns the latest system message beyond the instructions" do
    @chat.llm_messages.create!(role: "system", content: "You are Balance.")
    @chat.llm_messages.create!(role: "system", content: "Salary pending.")

    assert_equal "Salary pending.", @chat.current_summary.content
  end

  test "instruction replacement updates instructions and keeps the summary" do
    instructions = @chat.llm_messages.create!(role: "system", content: "old instructions")
    summary = @chat.llm_messages.create!(role: "system", content: "Salary pending.")

    @chat.send(:replace_persisted_system_instructions, "new instructions")

    assert_equal "new instructions", instructions.reload.content
    assert_equal "Salary pending.", summary.reload.content
  end

  test "estimates tokens from character count plus per-message overhead" do
    assert_equal 30, Llm::Chat.estimated_tokens("x" * 100)
  end

  test "folding the head brings the history back under the compaction threshold" do
    stub_const(Llm::Chat, :CONTEXT_WINDOW_TOKENS, 4_000) do
      stub_const(Llm::Chat, :TAIL_BUDGET_TOKENS, 2_400) do
        12.times { |number| build_turn(number + 1, weight: 1_000) }
        assert @chat.needs_compaction?

        head = @chat.foldable_head
        Llm::Message.where(id: head.map(&:id)).update_all(summarized_at: Time.current)
        @chat.llm_messages.create!(role: "system", content: "Anchored summary")

        refute @chat.needs_compaction?
      end
    end
  end
end
