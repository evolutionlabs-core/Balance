module Llm::MessagesHelper
  PROPOSAL_PARTIALS = {
    "account_creation" => "llm/messages/proposals/account_creation",
    "reversal_confirmation" => "llm/messages/proposals/reversal_confirmation",
    "entry" => "llm/messages/proposals/entry"
  }.freeze

  TOOL_LABELS = {
    running: {
      "get_balance_summary" => "Calculating your balance…",
      "list_accounts" => "Checking your accounts…",
      "propose_account" => "Preparing an account proposal…",
      "list_journal_entries" => "Checking posted entries…",
      "propose_reversal" => "Preparing the entry confirmation…",
      "propose_entry" => "Working out the entry…",
      "confirm_proposal" => "Recording the approved entry…"
    },
    completed: {
      "get_balance_summary" => "Calculated your balance",
      "list_accounts" => "Checked your accounts",
      "propose_account" => "Prepared the account proposal",
      "list_journal_entries" => "Checked posted entries",
      "propose_reversal" => "Selected the entry for confirmation",
      "propose_entry" => "Prepared the journal entry",
      "confirm_proposal" => "Recorded the journal entry"
    }
  }.freeze

  def default_model_display_name
    model = RubyLLM.models.find(RubyLLM.config.default_model)
    "Default: #{model.label}"
  rescue RubyLLM::ModelNotFoundError
    "Default: #{RubyLLM.config.default_model}"
  end

  def tool_running_label(tool_name) = TOOL_LABELS[:running][tool_name] || tool_name.to_s.humanize
  def tool_completed_label(tool_name) = TOOL_LABELS[:completed][tool_name] || tool_name.to_s.humanize

  def tool_detail_items(tool_name, output)
    case tool_name
    when "list_accounts"
      Array(output&.dig(:existing_accounts)).filter_map { |account| account[:name] }
    when "list_journal_entries"
      Array(output).filter_map do |entry|
        next unless entry.is_a?(Hash)

        [ entry[:date], entry[:description] ].compact.join(" · ")
      end
    when "get_balance_summary"
      output&.dig(:periods).to_h.map do |period, values|
        "#{period}: income #{values[:income_naira]}, expenses #{values[:expense_naira]}, net #{values[:net_naira]}"
      end
    when "check_proposal_status"
      Array(output).filter_map do |proposal|
        next unless proposal.is_a?(Hash)

        [ proposal[:description], proposal[:status] ].compact.join(" · ")
      end
    else
      message = output[:error] || output[:message] if output.is_a?(Hash)
      Array(message)
    end
  end

  def assistant_content(content)
    html = Commonmarker.to_html(
      content.to_s,
      options: {
        parse: { smart: true },
        render: { hardbreaks: false, unsafe: false }
      }
    )

    sanitize(
      html,
      tags: %w[p br strong em a ul ol li h1 h2 h3 h4 blockquote pre code table thead tbody tr th td hr del],
      attributes: %w[href title class]
    )
  end

  def user_correction_request?(content)
    content.to_s.match?(/\b(undo|reverse|reversal|correct|mistake)\b/i)
  end

  def proposal_response_content(proposal)
    messages = proposal.llm_chat.llm_messages
      .where(role: "assistant")
      .where.not(content: [ nil, "" ])
    messages = messages.where("id < ?", proposal.llm_message_id) if proposal.llm_message_id
    message = messages.order(:id).last

    message&.content.presence || proposal.description
  end

  def render_timeline_item(item)
    case item[:type]
    when :message
      partial = item[:record].role == "user" ? "llm/messages/user" : "llm/messages/assistant"
      render partial, item[:record].role.to_sym => item[:record]
    when :activity
      render "llm/messages/activity", activity: item[:record]
    when :tool_call
      output = item[:record].display_output
      render "llm/messages/tool_execution",
        tool_call_id: item[:record].tool_call_id,
        tool_name: item[:record].name,
        state: item[:record].trace_failed? ? :failed : :completed,
        output: output
    when :proposal
      render_proposal(item[:record])
    when :turn
      render "llm/messages/turn_status", turn: item[:record]
    end
  end

  def render_proposal(proposal)
    partial = PROPOSAL_PARTIALS[proposal.proposal_type] || "llm/messages/proposals/#{proposal.proposal_type}"
    render partial, proposal: proposal
  end
end
