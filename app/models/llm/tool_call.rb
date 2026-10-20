# Read model over RubyLLM's tool-call records, adding the run trace the chat
# timeline shows. RubyLLM writes these rows; the app only adds the trace.
class Llm::ToolCall < ApplicationRecord
  self.table_name = "ruby_llm_tool_calls"

  belongs_to :message, polymorphic: true
  belongs_to :llm_message, class_name: "Llm::Message", foreign_key: :message_id, optional: true
  belongs_to :result_message, class_name: "Llm::Message", foreign_key: :result_id, optional: true

  def display_output
    return symbolize_output(trace_output) if trace_output.present?
    return if result_message&.content.blank?

    JSON.parse(result_message.content, symbolize_names: true)
  rescue JSON::ParserError
    result_message.content
  end

  def trace_failed?
    trace_status == "failed" || display_output.is_a?(Hash) && display_output[:error].present?
  end

  private

  def symbolize_output(value)
    case value
    when Array
      value.map { |item| symbolize_output(item) }
    when Hash
      value.deep_symbolize_keys
    else
      value
    end
  end
end
