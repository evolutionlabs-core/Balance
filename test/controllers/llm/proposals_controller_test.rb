require "test_helper"

class Llm::ProposalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)

    @ledger = @workspace.provision_ledger!
    @cash = @ledger.accounts.find_by!(name: "Cash")
    @groceries = @ledger.accounts.find_by!(name: "Groceries")
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Test model"),
      title: "Test chat"
    )
    @proposal = @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "entry",
      version: 1,
      data: {
        "description" => "Gift to girlfriend",
        "effective_date" => Date.current.to_s,
        "lines" => [
          { "account_id" => @groceries.id, "side" => "debit", "amount_kobo" => 200_000 },
          { "account_id" => @cash.id, "side" => "credit", "amount_kobo" => 200_000 }
        ]
      }
    )
  end

  test "update accepts the indexed lines hash" do
    patch chat_proposal_path(@chat, @proposal), params: { proposal: form_params }

    assert_redirected_to chat_path(@chat)
    assert_equal 2, @proposal.reload.data["lines"].size
  end

  test "confirm posts the entry when two lines are submitted" do
    assert_difference "JournalEntry.count", 1 do
      patch chat_proposal_confirmation_path(@chat, @proposal), params: { proposal: form_params }
    end

    assert_redirected_to chat_path(@chat)
    assert_equal "confirmed", @proposal.reload.status
    assert_not_nil @proposal.journal_entry
    assert_equal 2, @proposal.journal_entry.journal_entry_lines.size
  end

  test "confirm with a single line reports an error and posts nothing" do
    params = form_params
    params[:lines].delete("1")

    assert_no_difference "JournalEntry.count" do
      patch chat_proposal_confirmation_path(@chat, @proposal),
            params: { proposal: params },
            headers: { Accept: "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "An entry requires at least two lines", response.body
    assert_equal "proposed", @proposal.reload.status
  end

  test "a reversal proposal cannot be edited" do
    reversal = reversal_proposal
    original_data = reversal.data.deep_dup

    patch chat_proposal_path(@chat, reversal),
      params: { proposal: form_params },
      headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal original_data, reversal.reload.data
    assert_no_match "Save edits", response.body
    assert_no_match "proposal\[lines\]", response.body
    assert_match "Record reversal", response.body
  end

  test "confirming a reversal ignores crafted form changes" do
    reversal = reversal_proposal

    assert_difference "JournalEntry.count", 1 do
      patch chat_proposal_confirmation_path(@chat, reversal), params: { proposal: form_params }
    end

    recorded = reversal.reload.journal_entry
    assert_equal @source_entry.id, reversal.data.fetch("reverses_journal_entry_id")
    assert_equal "Reversal of entry #{@source_entry.id}: Lunch", recorded.description
    assert_equal 5_000, recorded.journal_entry_lines.find_by!(debit: 5_000).debit
    assert_equal 5_000, recorded.journal_entry_lines.find_by!(credit: 5_000).credit
  end

  test "confirming a selected entry creates a reversal proposal but requires a second approval to post" do
    confirmation = source_confirmation

    assert_no_difference "JournalEntry.count" do
      assert_difference "Proposal.count", 1 do
        patch chat_proposal_confirmation_path(@chat, confirmation),
          headers: { Accept: "text/vnd.turbo-stream.html" }
      end
    end

    assert_response :success
    assert_match "Entry confirmed", response.body
    assert_match "Record reversal", response.body
    assert_no_match "Save edits", response.body
    assert_no_match "proposal\[lines\]", response.body
    reversal = @chat.proposals.find(confirmation.reload.data.fetch("reversal_proposal_id"))
    assert reversal.reversal_proposal?
    assert_equal @source_entry.id, reversal.data.fetch("reverses_journal_entry_id")
    assert_equal "superseded", @proposal.reload.status

    assert_no_difference [ "Proposal.count", "JournalEntry.count" ] do
      patch chat_proposal_confirmation_path(@chat, confirmation)
    end

    assert_difference "JournalEntry.count", 1 do
      patch chat_proposal_confirmation_path(@chat, reversal)
    end
    assert @source_entry.id, reversal.reload.data.fetch("reverses_journal_entry_id")
  end

  test "selection confirmation fields cannot be edited" do
    confirmation = source_confirmation
    original_data = confirmation.data.deep_dup

    patch chat_proposal_path(@chat, confirmation),
      params: { proposal: form_params },
      headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_equal original_data, confirmation.reload.data
    assert_match "Confirm this entry", response.body
    assert_match "Entry ##{@source_entry.id}", response.body
    assert_no_match "Save edits", response.body
  end

  test "a dismissed selection cannot create a reversal proposal" do
    confirmation = source_confirmation
    patch chat_proposal_dismissal_path(@chat, confirmation)

    assert_no_difference [ "Proposal.count", "JournalEntry.count" ] do
      patch chat_proposal_confirmation_path(@chat, confirmation)
    end
    assert_equal "dismissed", confirmation.reload.status
  end

  test "confirming an account proposal creates the account and resumes the transaction" do
    user_message = @chat.llm_messages.create!(role: "user", content: "I paid 2000 rent in cash")
    source_turn = @chat.llm_turns.create!(
      user_message: user_message,
      status: "completed",
      completed_at: Time.current
    )
    proposal_message = @chat.llm_messages.create!(role: "assistant", content: "", response_turn: source_turn)
    proposal = @chat.proposals.create!(
      workspace: @workspace,
      llm_message: proposal_message,
      proposal_type: "account_creation",
      version: 1,
      data: {
        "reason" => "Rent needs its own expense account.",
        "accounts" => [ {
          "name" => "Rent & Housing",
          "base_type" => "expense",
          "subtype" => "housing"
        } ]
      }
    )

    assert_difference "Account.count", 1 do
      assert_enqueued_with(job: LlmChatResponseJob, args: ->(args) { args.first == @chat.id && args.second.is_a?(Integer) }) do
        patch chat_proposal_confirmation_path(@chat, proposal), headers: { Accept: "text/vnd.turbo-stream.html" }
      end
    end

    assert_response :success
    assert_match "Created and ready to use", response.body
    assert_equal "confirmed", proposal.reload.status
    assert_equal "Rent & Housing", proposal.data.dig("created_accounts", 0, "name")
    assert_match "approved the account proposal", @chat.llm_messages.where(role: "system").last.content

    resumed_turn = @chat.llm_turns.order(:id).last
    assert_equal "queued", resumed_turn.status
    assert_equal "system", resumed_turn.user_message.role
    assert_match "Continue the pending transaction", resumed_turn.user_message.content
  end

  test "confirming a standalone account proposal does not start a transaction turn" do
    proposal = @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "account_creation",
      version: 1,
      data: {
        "reason" => "Track rent separately.",
        "accounts" => [ {
          "name" => "Rent & Housing",
          "base_type" => "expense",
          "subtype" => "housing"
        } ]
      }
    )

    assert_no_difference "Llm::Turn.count" do
      patch chat_proposal_confirmation_path(@chat, proposal)
    end

    assert_equal "confirmed", proposal.reload.status
  end

  test "dismissing an account proposal creates nothing" do
    proposal = @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "account_creation",
      version: 1,
      data: {
        "reason" => "Rent needs its own expense account.",
        "accounts" => [ {
          "name" => "Rent & Housing",
          "base_type" => "expense",
          "subtype" => "housing"
        } ]
      }
    )

    assert_no_difference "Account.count" do
      patch chat_proposal_dismissal_path(@chat, proposal)
    end

    assert_equal "dismissed", proposal.reload.status
  end

  private
    def source_confirmation
      @source_entry = record_entry(description: "Lunch")
      @chat.proposals.create!(
        workspace: @workspace,
        proposal_type: "reversal_confirmation",
        data: Llm::ReversalConfirmation.entry_data(@source_entry)
      )
    end

    def reversal_proposal
      @source_entry = record_entry(description: "Lunch")

      @chat.proposals.create!(
        workspace: @workspace,
        proposal_type: "entry",
        version: 2,
        data: {
          "description" => "Reversal of entry #{@source_entry.id}: Lunch",
          "effective_date" => Date.current.to_s,
          "amount_source" => "existing_posted_entry",
          "reverses_journal_entry_id" => @source_entry.id,
          "lines" => [
            { "account_id" => @cash.id, "side" => "debit", "amount_kobo" => 5_000 },
            { "account_id" => @groceries.id, "side" => "credit", "amount_kobo" => 5_000 }
          ]
        }
      )
    end

    def record_entry(description:, amount_kobo: 5_000)
      data = {
        "description" => description,
        "effective_date" => Date.current.to_s,
        "lines" => [
          { "account_id" => @groceries.id, "side" => "debit", "amount_kobo" => amount_kobo },
          { "account_id" => @cash.id, "side" => "credit", "amount_kobo" => amount_kobo }
        ]
      }
      proposal = @chat.proposals.create!(
        workspace: @workspace,
        proposal_type: "entry",
        version: (@chat.proposals.maximum(:version) || 0) + 1,
        data: data
      )
      assert_nil proposal.confirm!(draft: Llm::EntryProposal.new(workspace: @workspace, data: proposal.data))
      proposal.reload.journal_entry
    end

    def form_params
      {
        description: "Gift to girlfriend - N2,000 cash spent today",
        effective_date: Date.current.to_s,
        lines: {
          "0" => { account_id: @groceries.id, side: "debit", amount_naira: "2000.00" },
          "1" => { account_id: @cash.id, side: "credit", amount_naira: "2000.00" }
        }
      }
    end
end
