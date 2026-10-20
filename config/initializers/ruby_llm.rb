RubyLLM.configure do |config|
  # Local model served by LM Studio by default. Docker overrides the endpoint
  # so the container can reach the host machine.
  config.openai_api_base = ENV.fetch("OPENAI_API_BASE", "http://127.0.0.1:1234/v1")
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY", "lm-studio")
  config.default_model = ENV.fetch("OPENAI_MODEL", "qwen3.5-35b-a3b")

  # RubyLLM 2 defaults OpenAI to the Responses API. OpenAI-compatible local
  # servers such as LM Studio speak Chat Completions.
  config.openai_protocol = :chat_completions
end

# LM Studio occasionally sends an SSE error event with an empty data line.
# Upstream logs the unparseable payload and carries on, so the turn ends with
# an empty response instead of an error. Treat it as a provider error so
# ChatTurn's normal retry loop handles it.
module RubyLLM
  class Protocol
    module Streaming
      private

      def handle_error_event(data, env)
        raise RubyLLM::Error, "Provider stream error: #{data.inspect}" if data.blank?

        parse_error_from_json(data, env, "Failed to parse error event")
      end
    end
  end
end
