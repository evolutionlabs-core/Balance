module LlmChatTestHelper
  FakeMessage = Struct.new(:role, :content)

  def post_entry_proposal!(
    chat,
    description: "Test entry",
    effective_date: Date.current,
    debit_ledger_account:,
    credit_ledger_account:,
    amount_kobo:
  )
    workspace = chat.workspace
    proposal = chat.proposals.create!(
      workspace: workspace,
      proposal_type: "entry",
      data: {
        "description" => description,
        "effective_date" => effective_date.iso8601,
        "amount_source" => "user_provided",
        "lines" => [
          { "ledger_account_id" => debit_ledger_account.id, "side" => "debit", "amount_kobo" => amount_kobo },
          { "ledger_account_id" => credit_ledger_account.id, "side" => "credit", "amount_kobo" => amount_kobo }
        ]
      }
    )
    draft = Llm::EntryProposal.new(workspace: workspace, data: proposal.data)
    errors = proposal.confirm!(draft: draft)
    raise "Entry proposal rejected: #{errors.join(', ')}" if errors.present?

    proposal.reload
  end

  class FakeLlmMessages
    def initialize(messages)
      @messages = messages
    end

    def where(role: nil)
      filtered = role ? @messages.select { |message| message.role == role } : @messages
      FakeLlmMessages.new(filtered)
    end

    def not(content:)
      excluded = Array(content)
      FakeLlmMessages.new(@messages.reject { |message| excluded.include?(message.content) })
    end

    def order(*)
      self
    end

    def pluck(column)
      @messages.map { |message| message.public_send(column) }
    end

    def last
      @messages.last
    end

    def to_a
      @messages
    end
  end

  def stub_llm_chat(workspace:, prompt:)
    stub_llm_chat_with_messages(workspace:, messages: [ FakeMessage.new("user", prompt) ])
  end

  def stub_llm_chat_with_messages(workspace:, messages:)
    Struct.new(:workspace, :llm_messages).new(workspace, FakeLlmMessages.new(messages))
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include LlmChatTestHelper
end
