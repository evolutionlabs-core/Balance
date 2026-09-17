require "digest"

module Llm
  module Harness
    # Orchestrates a full live evaluation: config overrides, corpus loading,
    # sequential case execution against the real pipeline, artifact writing,
    # and aggregate reporting.
    #
    #   bin/harness-benchmark
    #   HARNESS_EVAL_MODEL=qwen3-30b HARNESS_EVAL_BASE_URL=http://127.0.0.1:1234/v1 \
    #     bin/harness-benchmark
    class LiveRunner
      SOURCE_PATHS = %w[
        lib/benchmark/harness/journal_entry_examples.md
        lib/benchmark/harness/transactions.yml
      ].freeze

      def initialize(case_ids: [], model_id: nil, base_url: nil)
        @case_ids = case_ids
        @requested_model = model_id.presence || RubyLLM.config.default_model
        @requested_base_url = base_url.presence
        @repetitions = ENV.fetch("HARNESS_EVAL_RUNS", "3").to_i.clamp(1, 10)
        @split = ENV.fetch("HARNESS_SPLIT", "all")
        @run_label = Time.current.utc.strftime("%Y%m%d-%H%M%S")
        $stdout.sync = true
      end

      def run
        apply_config_overrides!
        @llm_model = resolve_llm_model!
        cases = load_cases
        puts "harness_eval: validated #{cases.size} transactions from lib/benchmark/harness/journal_entry_examples.md"
        output_dir = prepare_artifacts

        meta = build_meta(cases, @llm_model)
        executions = cases.product((1..@repetitions).to_a)
        puts "harness_eval: model=#{@requested_model} base=#{RubyLLM.config.openai_api_base} cases=#{cases.size} runs=#{@repetitions} dir=#{output_dir}"

        entries = executions.each_with_index.map do |(test_case, run_index), index|
          execute_one(test_case, output_dir, "#{index + 1}/#{executions.size}", run_index)
        end

        summary = ReportBuilder.new(entries: entries, meta: meta, output_dir: output_dir).call
        print_summary(summary, output_dir)
        summary
      end

      private

      def apply_config_overrides!
        RubyLLM.config.openai_api_base = @requested_base_url if @requested_base_url
        RubyLLM.config.default_model = @requested_model
      end

      def resolve_llm_model!
        Llm::Model.find_by(provider: "openai", model_id: @requested_model) ||
          Llm::Model.create!(provider: "openai", model_id: @requested_model, name: @requested_model)
      end

      def load_cases
        cases = JournalExamplesCorpus.load!
        if @split != "all"
          cases = cases.select { |test_case| test_case.fetch("split", "dev") == @split }
        end
        return cases if @case_ids.empty?

        selected = cases.select { |test_case| @case_ids.include?(test_case.fetch("id")) }
        missing = @case_ids - selected.pluck("id")
        raise ArgumentError, "Unknown harness cases: #{missing.join(', ')}" if missing.any?

        selected
      end

      def prepare_artifacts
        dir = Rails.root.join(
          "tmp/benchmark/harness/#{@run_label}-#{@requested_model.gsub(/[^a-z0-9.-]/i, '_')}"
        )
        FileUtils.mkdir_p([ dir.join("transcripts"), dir.join("results") ])
        dir
      end

      def execute_one(test_case, output_dir, progress, run_index)
        case_id = test_case.fetch("id")
        suffix = @repetitions > 1 ? " run #{run_index}/#{@repetitions}" : ""
        print "harness_eval: #{progress} #{case_id}#{suffix} ... "

        capture = CaseExecutor.new(
          test_case: test_case,
          llm_model: @llm_model,
          run_label: @run_label,
          transcript_path: output_dir.join("transcripts/#{artifact_name(case_id, run_index)}.jsonl")
        ).call
        capture[:run_index] = run_index
        result = Scorer.new(test_case: test_case, capture: capture).result
        result["run_index"] = run_index

        write_result(output_dir, artifact_name(case_id, run_index), test_case, capture, result)
        score = result["overall"] || "—"
        puts "#{result['verdict']} (#{score})"

        { case: test_case, capture: json_capture(capture), result: result }
      rescue StandardError => e
        puts "ERROR #{e.class}: #{e.message}"
        {
          case: test_case,
          capture: {},
          result: {
            "case_id" => case_id, "outcome_expected" => test_case.dig("expected", "outcome"),
            "run_index" => run_index,
            "scores" => Scorer::CATEGORIES.index_with { 0 }, "overall" => 0.0, "verdict" => "FAIL",
            "note" => "executor crashed: #{e.class}: #{e.message}", "observed" => {}
          }
        }
      end

      def artifact_name(case_id, run_index)
        @repetitions > 1 ? "#{case_id}-run-#{run_index}" : case_id
      end

      def write_result(output_dir, case_id, test_case, capture, result)
        output_dir.join("results/#{case_id}.json").write(
          JSON.pretty_generate("case" => test_case, "capture" => json_capture(capture), "result" => result)
        )
      end

      def json_capture(capture)
        jsonable = capture.dup
        jsonable[:proposals_created] = capture[:proposals_created].map do |proposal|
          { "id" => proposal.id, "type" => proposal.proposal_type, "status" => proposal.status,
            "version" => proposal.version, "data" => proposal.data }
        end
        deep_stringify(jsonable)
      end

      def deep_stringify(value)
        case value
        when Hash then value.to_h { |key, item| [ key.to_s, deep_stringify(item) ] }
        when Array then value.map { |item| deep_stringify(item) }
        else value
        end
      end

      def build_meta(cases, llm_model)
        {
          "started_at_utc" => Time.current.utc.iso8601,
          "model" => llm_model.model_id,
          "provider" => llm_model.provider,
          "base_url" => RubyLLM.config.openai_api_base,
          "requested_base_url_override" => @requested_base_url || "none",
          "ruby_version" => RUBY_VERSION,
          "rails_version" => Rails.version,
          "git_sha" => git_sha,
          "git_dirty" => git_dirty?,
          "implementation_fingerprint" => implementation_fingerprint,
          "repetitions" => @repetitions,
          "split" => @split,
          "timeout_seconds" => Llm::ChatTurn::TIMEOUT_SECONDS,
          "source_files" => SOURCE_PATHS,
          "source_examples" => cases.pluck("source_example").uniq.size,
          "source_entries" => cases.size,
          "expected_journal_lines" => cases.sum { |test_case| Array(test_case["expect_lines"]).size }
        }
      end

      def git_sha
        `git rev-parse --short HEAD`.strip
      rescue StandardError
        "unknown"
      end

      def git_dirty?
        `git status --porcelain`.present?
      rescue StandardError
        nil
      end

      def implementation_fingerprint
        paths = SOURCE_PATHS + %w[
          lib/benchmark/harness/journal_examples_corpus.rb
          app/prompts/ledger_agent/instructions.txt.erb
          app/services/llm/chat_turn.rb
          lib/benchmark/harness/case_executor.rb
          lib/benchmark/harness/scorer.rb
          lib/benchmark/harness/transcript_recorder.rb
          lib/benchmark/harness/live_runner.rb
          lib/benchmark/harness/report_builder.rb
          lib/benchmark/harness/response_contract.rb
          lib/benchmark/harness/semantic_judges.rb
          app/tools/list_accounts.rb
          app/tools/propose_account.rb
          app/tools/propose_entry.rb
          app/tools/propose_reversal.rb
        ]
        content = paths.filter_map do |path|
          file = Rails.root.join(path)
          "#{path}\0#{file.read}" if file.exist?
        end.join("\0")
        Digest::SHA256.hexdigest(content).first(16)
      end

      def print_summary(summary, output_dir)
        totals = summary["totals"]
        ci = totals.dig("pass_rate_ci95", "half_width_pp")
        puts <<~SUMMARY
          harness_eval: done — pass #{totals['passed']}/#{totals['evaluated']} (#{totals['pass_rate']}% ±#{ci || '—'}pp 95% CI), infra #{totals['infrastructure_errors']}, overall avg #{totals['overall_average']}
          harness_eval: report #{output_dir.join('report.md')} csv #{output_dir.join('results.csv')}
        SUMMARY
      end
    end
  end
end
