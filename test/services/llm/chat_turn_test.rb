require "test_helper"

class Llm::ChatTurnTest < ActiveSupport::TestCase
  FakeToolCall = Struct.new(:id, :name)

  class FakeAgent
    attr_reader :completions

    def initialize(chat, contents)
      @persisted_chat = chat
      @contents = contents
      @completions = 0
    end

    def before_tool_call(&block); end

    def after_tool_result(&block); end

    def with_tools(*, replace:)
      self
    end

    def chat = self
    def with_runtime_instructions(*, append:) = self

    def complete
      @completions += 1
      @persisted_chat.llm_messages.create!(role: "assistant", content: @contents.shift)
    end
  end

  class ContextOverflowAgent
    attr_reader :completions

    def initialize(chat, fail_forever: false)
      @persisted_chat = chat
      @fail_forever = fail_forever
      @completions = 0
    end

    def before_tool_call(&block); end

    def after_tool_result(&block); end

    def with_tools(*, replace:)
      self
    end

    def chat = self
    def with_runtime_instructions(*, append:) = self

    def complete
      @completions += 1
      if @fail_forever || @completions == 1
        raise RubyLLM::ContextLengthExceededError.new(nil, "Context length exceeded")
      end

      @persisted_chat.llm_messages.create!(role: "assistant", content: "Here you go.")
    end
  end

  class ToolLoopAgent
    attr_reader :completions

    def initialize(chat, tool_calls)
      @persisted_chat = chat
      @tool_calls = tool_calls
      @before_tool_call = nil
      @completions = 0
    end

    def before_tool_call(&block)
      @before_tool_call = block
    end

    def after_tool_result(&block); end

    def with_tools(*, replace:)
      self
    end

    def chat = self
    def with_runtime_instructions(*, append:) = self

    def complete
      @completions += 1
      @tool_calls.times do |number|
        @before_tool_call.call(FakeToolCall.new("tool_call_#{number}", "list_journal_entries"))
      end
      @persisted_chat.llm_messages.create!(role: "assistant", content: "Here you go.")
    end
  end

  setup do
    @workspace = workspaces(:ada_store)
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Test model"),
      title: "Test chat"
    )
  end

  def build_fat_turn(number)
    @chat.llm_messages.create!(role: "user", content: "user #{number}")
    @chat.llm_messages.create!(role: "tool", content: "x" * 1_000)
  end

  def process(agent, compactor: nil)
    message = @chat.llm_messages.create!(role: "user", content: "test request")
    turn = @chat.llm_turns.create!(user_message: message)
    Llm::ChatTurn.new(
      chat: @chat,
      turn: turn,
      agent: agent,
      compactor: compactor
    ).call
  end

  def assistant_contents
    @chat.visible_messages.where(role: "assistant").pluck(:content)
  end

  test "finish_tool_call feeds an error result back to the model instead of raising" do
    message = @chat.llm_messages.create!(role: "user", content: "Paid 2000")
    record = @chat.llm_turns.create!(user_message: message)
    turn = Llm::ChatTurn.new(chat: @chat, turn: record)
    turn.send(:start_tool_call, FakeToolCall.new("tool_call_1", "propose_entry"))

    result = turn.send(:finish_tool_call, { error: "Ask for the amount before proposing an entry." })

    assert_equal "Ask for the amount before proposing an entry.", result[:error]
    assert_nil turn.instance_variable_get(:@current_tool_call)
    refute @chat.llm_messages.exists?(role: "assistant", content: "Ask for the amount before proposing an entry.")
  end

  test "retries a silent completion once and writes a fallback when it stays silent" do
    agent = FakeAgent.new(@chat, [ "", "" ])

    process(agent)

    assert_equal 2, agent.completions
    assert_equal [ "The accounting assistant is temporarily unavailable. Please try again." ], assistant_contents
  end

  test "retries a silent completion and keeps a real reply when the retry responds" do
    agent = FakeAgent.new(@chat, [ "", "Here you go." ])

    process(agent)

    assert_equal 2, agent.completions
    assert_equal [ "Here you go." ], assistant_contents
  end

  test "remove_empty_assistant_messages destroys empty messages without tool calls and keeps those with tool calls" do
    bare = @chat.llm_messages.create!(role: "assistant", content: "")
    with_tool = @chat.llm_messages.create!(role: "assistant", content: "")
    with_tool.llm_tool_calls.create!(tool_call_id: "tool_call_2", name: "propose_entry", arguments: {})
    keeps = @chat.llm_messages.create!(role: "user", content: "")

    Llm::ChatBroadcaster.new(@chat).remove_empty_assistant_messages

    refute Llm::Message.exists?(bare.id), "empty assistant message without tool calls should be destroyed"
    assert Llm::Message.exists?(with_tool.id), "empty assistant message with tool calls should be kept"
    assert Llm::Message.exists?(keeps.id), "user messages should be untouched"
  end

  test "compacts and retries once after a context length error" do
    agent = ContextOverflowAgent.new(@chat)
    compactor = Minitest::Mock.new
    compactor.expect(:call, true)

    process(agent, compactor: compactor)
    compactor.verify

    assert_equal 2, agent.completions
    assert_equal [ "Here you go." ], assistant_contents
  end

  test "reports a generic failure when compaction cannot help the overflow" do
    agent = ContextOverflowAgent.new(@chat, fail_forever: true)
    compactor = Object.new
    compactor.define_singleton_method(:call) { false }

    process(agent, compactor: compactor)

    assert_equal 1, agent.completions
    assert_equal [ "The accounting assistant is temporarily unavailable. Please try again." ],
      assistant_contents
  end

  test "reports an honest retry hint when the turn fails unexpectedly" do
    agent = Object.new
    agent.define_singleton_method(:before_tool_call) { |&_block| }
    agent.define_singleton_method(:after_tool_result) { |&_block| }
    agent.define_singleton_method(:with_tools) { |*, replace:| self }
    agent.define_singleton_method(:chat) { self }
    agent.define_singleton_method(:with_runtime_instructions) { |*, append:| self }
    agent.define_singleton_method(:complete) { |&_block| raise "boom" }

    process(agent)

    assert_equal [ "I hit a problem while answering. Please try again." ],
      assistant_contents
  end

  test "does not impose an application tool-call limit" do
    agent = ToolLoopAgent.new(@chat, 25)

    process(agent)

    assert_equal 1, agent.completions
    assert_equal [ "Here you go." ], assistant_contents
  end

  test "lets a turn with tool calls under the limit complete normally" do
    agent = ToolLoopAgent.new(@chat, 5)

    process(agent)

    assert_equal 1, agent.completions
    assert_equal [ "Here you go." ], assistant_contents
  end

  test "compacts before the turn when history is over budget" do
    stub_const(Llm::Chat, :CONTEXT_WINDOW_TOKENS, 4_000) do
      12.times { |number| build_fat_turn(number + 1) }
      agent = FakeAgent.new(@chat, [ "Here you go." ])
      compactor = Minitest::Mock.new
      compactor.expect(:call, true)

      process(agent, compactor: compactor)
      compactor.verify

      assert_equal "Here you go.", @chat.visible_messages.pluck(:content).last
    end
  end

  test "leaves history untouched when it fits the budget" do
    3.times do |number|
      @chat.llm_messages.create!(role: "user", content: "user #{number}")
      @chat.llm_messages.create!(role: "assistant", content: "assistant #{number}")
    end
    agent = FakeAgent.new(@chat, [ "Here you go." ])
    compactor = Object.new
    compactor.define_singleton_method(:call) { flunk "must not compact when history fits" }

    process(agent, compactor: compactor)

    assert_equal "Here you go.", @chat.visible_messages.pluck(:content).last
  end
end
