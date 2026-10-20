require "test_helper"

class RubyLlmStreamingTest < ActiveSupport::TestCase
  def protocol
    @protocol ||= RubyLLM::Protocols::ChatCompletions.new(RubyLLM::Providers::OpenAI.new(RubyLLM.config))
  end

  test "raises a provider error when an error event has no data" do
    error = assert_raises(RubyLLM::Error) do
      protocol.send(:handle_error_event, nil, nil)
    end

    assert_includes error.message, "Provider stream error"
  end

  test "raises a provider error when the error data is empty" do
    assert_raises(RubyLLM::Error) do
      protocol.send(:handle_error_event, " ", nil)
    end
  end

  test "still parses a well-formed error event" do
    error = assert_raises(RubyLLM::Error) do
      protocol.send(:handle_error_event, "{\"error\":{\"message\":\"boom\"}}", nil)
    end

    refute_includes error.message, "Provider stream error"
    assert_includes error.message, "boom"
  end

  test "parses a split error event as one event" do
    events = []
    parser = RubyLLM::Transport::EventStreamParser.new
    parser.feed("event: error\n") { |type, data| events << [ type, data ] }
    parser.feed("data: {\"error\":{\"message\":\"boom\"}}\n\n") { |type, data| events << [ type, data ] }

    assert_equal [ [ "error", "{\"error\":{\"message\":\"boom\"}}" ] ], events.map { |type, data| [ type.to_s, data ] }
  end
end
