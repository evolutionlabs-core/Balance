module Llm
  module Harness
    # Thread-safe event recorder for one case execution. Attached to the agent's
    # tool callbacks (RubyLLM appends callbacks, so ChatTurn keeps working) and
    # writes every event as a JSON line for a per-case transcript.
    class TranscriptRecorder
      def initialize(transcript_path:)
        @transcript_path = transcript_path
        @mutex = Mutex.new
        @events = []
        @active_by_thread = {}
      end

      def attach(agent)
        agent.before_tool_call { |tool_call| tool_call_started(tool_call) }
        agent.after_tool_result { |result| tool_call_finished(result) }
        self
      end

      def event(type, **fields)
        write(type: type, at: timestamp, **fields)
        nil
      end

      def events
        @mutex.synchronize { @events.dup }
      end

      def tool_events
        events.select { |event| event["type"] == "tool_call_finished" }
      end

      def crash?
        events.any? { |event| event["type"] == "crash" }
      end

      private

      def tool_call_started(tool_call)
        @mutex.synchronize do
          @active_by_thread[Thread.current.object_id] = {
            "name" => tool_call.name.to_s,
            "started_at" => Process.clock_gettime(Process::CLOCK_MONOTONIC)
          }
          write(type: "tool_call_started", at: timestamp, tool: tool_call.name.to_s)
        end
        nil
      end

      def tool_call_finished(result)
        payload = normalise(result)
        @mutex.synchronize do
          started = @active_by_thread.delete(Thread.current.object_id) || @active_by_thread.shift&.last
          write(
            type: "tool_call_finished",
            at: timestamp,
            tool: started&.dig("name"),
            duration_ms: duration_ms(started),
            error: payload.is_a?(Hash) && payload.key?("error"),
            result: payload
          )
        end
        nil
      end

      def duration_ms(started)
        return nil unless started

        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started["started_at"]) * 1000).round
      end

      def write(fields)
        record = deep_stringify(fields)
        @events << record
        File.open(@transcript_path, "a") { |io| io.puts(JSON.generate(record)) }
      end

      def deep_stringify(value)
        case value
        when Hash then value.to_h { |key, item| [ key.to_s, deep_stringify(item) ] }
        when Array then value.map { |item| deep_stringify(item) }
        else value
        end
      end

      def timestamp
        Time.current.utc.iso8601(6)
      end

      def normalise(value)
        case value
        when Hash then value.to_h { |key, item| [ key.to_s, normalise(item) ] }
        when Array then value.map { |item| normalise(item) }
        when NilClass, TrueClass, FalseClass, Integer, Float then value
        when String then value
        else value.to_s
        end
      end
    end
  end
end
