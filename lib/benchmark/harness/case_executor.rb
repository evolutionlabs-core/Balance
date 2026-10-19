module Llm
  module Harness
    # Runs one corpus case against the real pipeline: isolated Workspace with a
    # provisioned ledger, seeded ledger state, then the prompt delivered through
    # Llm::ChatTurn exactly as a Solid Queue job would drive it. Captures
    # everything the Scorer needs.
    class CaseExecutor
      FAILURE_PATTERNS = [
        /couldn't finish this request in time/,
        /temporarily unavailable/,
        /tool-call limit/,
        /hit a problem while answering/,
        /wasn't able to respond/
      ].freeze

      def initialize(test_case:, llm_model:, run_label:, transcript_path:)
        @test_case = test_case
        @llm_model = llm_model
        @run_label = run_label
        @recorder = TranscriptRecorder.new(transcript_path: transcript_path)
      end

      def call
        @recorder.event("case_started", case_id: @test_case.fetch("id"))
        @workspace = Workspace.create!(
          name: workspace_name,
          workspace_type: @test_case.fetch("workspace_type", "personal"),
          currency_code: "NGN"
        )
        @ledger = @workspace.provision_ledger!
        seed_posted_entries!
        @chat = @workspace.llm_chats.create!(llm_model: @llm_model, title: @test_case.fetch("id"))
        seed_pending_proposal! if seed_pending_proposal?
        replay_prior_messages!

        baseline = baseline_snapshot
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        deliver_prompt!
        run_turn
        wall_clock_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

        capture(baseline, wall_clock_ms)
      end

      private

      def workspace_name
        "[harness-eval] #{@run_label} · #{@test_case.fetch('id')}"
      end

      def setup
        @test_case["setup"] || {}
      end

      def seed_posted_entries!
        Array(setup["posted_entries"]).each do |spec|
          amount = spec.fetch("amount_kobo")
          cash = @ledger.accounts.find_by!(key: "cash")
          expense = @ledger.accounts.find_by!(key: "other_expense")

          Accounting.post(
            Accounting::Adapters::Entry.call(
              workspace: @workspace,
              attributes: {
                effective_date: Date.current,
                lines: [
                  { account_id: expense.id, debit: amount, credit: 0 },
                  { account_id: cash.id, debit: 0, credit: amount }
                ]
              },
              source_id: nil,
              description: spec["description"] || "Test entry"
            )
          )
        end
      end

      def seed_pending_proposal?
        setup.fetch("pending_entry_proposal", false)
      end

      def seed_pending_proposal!
        expense = @ledger.accounts.find_by!(key: "other_expense")
        cash = @ledger.accounts.find_by!(key: "cash")

        @workspace.proposals.create!(
          llm_chat: @chat,
          proposal_type: "entry",
          data: {
            "description" => "Pending expense",
            "effective_date" => Date.current.to_s,
            "lines" => [
              { "account_id" => expense.id, "side" => "debit", "amount_kobo" => 100_000 },
              { "account_id" => cash.id, "side" => "credit", "amount_kobo" => 100_000 }
            ]
          }
        )
      end

      def replay_prior_messages!
        Array(@test_case["prior_messages"]).each do |message|
          @chat.llm_messages.create!(role: message.fetch("role"), content: interpolate(message.fetch("content")))
        end
      end

      def interpolate(content)
        latest_id = @ledger.journal_entries.order(effective_date: :desc, id: :desc).pick(:id)
        content.gsub("{{latest_posted_id}}", latest_id.to_s)
      end

      # Everything after this point — user prompt, assistant replies, tool calls,
      # proposals — belongs to this case's turn.
      def baseline_snapshot
        {
          journal_entries: @ledger.journal_entries.count,
          accounts: @ledger.accounts.count,
          proposals_proposed: Proposal.where(workspace_id: @workspace.id).proposed.count,
          last_message_id: @chat.llm_messages.maximum(:id) || 0,
          max_proposal_id: Proposal.where(workspace_id: @workspace.id).maximum(:id) || 0
        }
      end

      def deliver_prompt!
        @recorder.event("prompt_delivered", content: @test_case.fetch("prompt"))
        message = @chat.llm_messages.create!(role: "user", content: @test_case.fetch("prompt"))
        @turn = @chat.llm_turns.create!(user_message: message)
      end

      def run_turn
        agent = LedgerAgent.new(chat: @chat)
        @recorder.attach(agent)
        Llm::ChatTurn.new(chat: @chat, turn: @turn, agent: agent).call
      rescue StandardError => e
        @recorder.event(
          "crash",
          error_class: e.class.name,
          message: e.message.to_s.slice(0, 500),
          backtrace_first: e.backtrace&.first
        )
        nil
      end

      def capture(baseline, wall_clock_ms)
        assistant = assistant_contents(baseline)

        {
          case_id: @test_case.fetch("id"),
          workspace_id: @workspace.id,
          chat_id: @chat.id,
          prompt: @test_case.fetch("prompt"),
          db_tool_calls: db_tool_calls(baseline),
          recorded_tool_events: @recorder.tool_events,
          crashed: @recorder.crash?,
          crash_error: crash_error,
          assistant_messages: assistant,
          final_response: assistant.last,
          failure_reported: assistant.select { |content| failure?(content) },
          infrastructure_failure: assistant.find { |content| content.match?(/temporarily unavailable/i) },
          journal_entries_delta: @ledger.journal_entries.count - baseline[:journal_entries],
          accounts_delta: @ledger.accounts.count - baseline[:accounts],
          proposals_created: created_proposals(baseline),
          superseded_count: superseded_count(baseline),
          wall_clock_ms: wall_clock_ms
        }
      end

      def db_tool_calls(baseline)
        Llm::ToolCall.joins(:llm_message)
          .where(llm_messages: { llm_chat_id: @chat.id })
          .where("llm_messages.id > ?", baseline[:last_message_id])
          .order(:id)
          .map { |call| { "name" => call.name, "arguments" => call.arguments } }
      end

      def assistant_contents(baseline)
        @chat.llm_messages
          .where(role: "assistant")
          .where("id > ?", baseline[:last_message_id])
          .order(:id)
          .pluck(:content)
          .compact
          .reject(&:blank?)
      end

      def created_proposals(baseline)
        Proposal.where(workspace_id: @workspace.id)
          .where("id > ?", baseline[:max_proposal_id])
          .order(:id).to_a
      end

      def superseded_count(baseline)
        [ baseline[:proposals_proposed] - Proposal.where(workspace_id: @workspace.id).proposed.count, 0 ].max
      end

      def crash_error
        @recorder.events.find { |event| event["type"] == "crash" }&.slice("error_class", "message")
      end

      def failure?(content)
        FAILURE_PATTERNS.any? { |pattern| content.match?(pattern) }
      end
    end
  end
end
