require "test_helper"

class Llm::ChatCompactorTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      model: ruby_llm_models(:default),
      title: "Compactor test"
    )
    @chat.llm_messages.create!(role: "system", content: "You are Balance.")
  end

  def build_turn(number, weight: 1)
    @chat.llm_messages.create!(role: "user", content: "user #{number}")
    @chat.llm_messages.create!(role: "assistant", content: "assistant #{number}")
    @chat.llm_messages.create!(role: "tool", content: "t" * weight) if weight > 1
  end

  test "folds the head into a summary anchored on the previous one" do
    stub_const(Llm::Chat, :TAIL_BUDGET_TOKENS, 300) do
      summarizer = lambda do |prompt, temperature: 0|
        assert_includes prompt, "<previous-summary>"
        assert_includes prompt, "[user] user 1"
        refute_includes prompt, "[assistant] assistant 4"
        "Anchored summary"
      end

      2.times { |number| build_turn(number + 1) }
      2.times { |number| build_turn(number + 3, weight: 1_000) }

      assert Llm::ChatCompactor.new(@chat, summarizer:).call

      assert_equal [ "user 4", "assistant 4", "t" * 1_000 ],
        @chat.llm_messages.where(summarized_at: nil).where.not(role: "system").pluck(:content)
      assert_equal "Anchored summary", @chat.current_summary.content
    end
  end

  test "chains each compaction onto the previous summary" do
    stub_const(Llm::Chat, :TAIL_BUDGET_TOKENS, 300) do
      prompts = []
      summarizer = ->(prompt, temperature: 0) { prompts << prompt; "Summary #{prompts.size}" }
      compactor = Llm::ChatCompactor.new(@chat, summarizer:)

      6.times { |number| build_turn(number + 1, weight: 1_000) }
      compactor.call
      6.times { |number| build_turn(number + 7, weight: 1_000) }
      compactor.call

      assert_equal 2, prompts.size
      assert_includes prompts.second, "Summary 1"
    end
  end

  test "does nothing when everything fits the tail budget" do
    stub_const(Llm::Chat, :TAIL_BUDGET_TOKENS, 300) do
      2.times { |number| build_turn(number + 1) }

      refute Llm::ChatCompactor.new(@chat, summarizer: ->(_prompt, temperature: 0) { flunk "must not summarize" }).call
    end
  end

  test "summarizes the head in bounded chunks chaining partials" do
    stub_const(Llm::Chat, :TAIL_BUDGET_TOKENS, 300) do
      stub_const(Llm::ChatCompactor, :MAX_HEAD_TOKENS, 50) do
        prompts = []
        summarizer = ->(prompt, temperature: 0) { prompts << prompt; "summ-#{prompts.size}" }
        3.times { |number| build_turn(number + 1, weight: 1_000) }

        assert Llm::ChatCompactor.new(@chat, summarizer:).call

        assert_equal 4, prompts.size
        assert_includes prompts.second, "summ-1"
        assert_equal "summ-4", @chat.current_summary.content
      end
    end
  end

  test "retries once at a warmer temperature when the summarizer returns nothing" do
    stub_const(Llm::Chat, :TAIL_BUDGET_TOKENS, 300) do
      calls = []
      summarizer = lambda do |prompt, temperature: 0|
        calls << temperature
        calls.size == 1 ? "" : "Retried summary"
      end

      2.times { |number| build_turn(number + 1) }
      2.times { |number| build_turn(number + 3, weight: 1_000) }

      assert Llm::ChatCompactor.new(@chat, summarizer:).call

      assert_equal [ 0, 0.1 ], calls
      assert_equal "Retried summary", @chat.current_summary.content
    end
  end

  test "stops without marking anything when the summarizer returns nothing" do
    stub_const(Llm::Chat, :TAIL_BUDGET_TOKENS, 300) do
      2.times { |number| build_turn(number + 1) }
      2.times { |number| build_turn(number + 3, weight: 1_000) }

      refute Llm::ChatCompactor.new(@chat, summarizer: ->(_prompt, temperature: 0) { "" }).call
      assert_nil @chat.current_summary
      assert_equal 0, @chat.llm_messages.where.not(summarized_at: nil).count
    end
  end
end
