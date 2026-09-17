module Llm
  module Harness
    # Aggregates per-case results into summary.json and a human-readable
    # report.md: pass rate, category averages, tool statistics, critical failures.
    class ReportBuilder
      CATEGORY_HEADERS = {
        "intent" => "intent", "tool_selection" => "tools", "proposal_quality" => "quality",
        "approval_handling" => "approval", "state_management" => "state", "safety" => "safety",
        "error_handling" => "errors", "final_outcome" => "final"
      }.freeze

      def initialize(entries:, meta:, output_dir:)
        @entries = entries
        @meta = meta
        @output_dir = output_dir
      end

      def call
        @output_dir.join("summary.json").write(JSON.pretty_generate(summary))
        @output_dir.join("report.md").write(markdown)
        @output_dir.join("results.csv").write(csv)
        summary
      end

      private

      def summary
        {
          "meta" => @meta,
          "totals" => totals,
          "category_averages" => category_averages,
          "tool_stats" => tool_stats,
          "critical_failures" => critical_failures,
          "results" => @entries.map { |entry| entry[:result] }
        }
      end

      def totals
        {
          "cases" => @entries.map { |entry| entry[:result]["case_id"] }.uniq.size,
          "executions" => @entries.size,
          "evaluated" => evaluated.size,
          "passed" => passes.size,
          "failed" => evaluated.size - passes.size,
          "infrastructure_errors" => infrastructure_errors.size,
          "pass_rate" => pass_rate,
          "pass_rate_ci95" => proportion_ci95(passes.size, evaluated.size),
          "overall_average" => average_of(evaluated) { |entry| entry[:result]["overall"] },
          "overall_sem" => sem_of(evaluated) { |entry| entry[:result]["overall"] }
        }
      end

      def passes
        @passes ||= evaluated.select { |entry| entry[:result]["verdict"] == "PASS" }
      end

      def evaluated
        @evaluated ||= @entries.select { |entry| %w[PASS FAIL].include?(entry[:result]["verdict"]) }
      end

      def infrastructure_errors
        @infrastructure_errors ||= @entries.select { |entry| entry[:result]["verdict"] == "INFRA_ERROR" }
      end

      def pass_rate
        return 0.0 if evaluated.empty?

        (passes.size.to_f / evaluated.size * 100).round(1)
      end

      def category_averages
        Scorer::CATEGORIES.index_with do |category|
          average_of(evaluated) { |entry| entry[:result]["scores"].fetch(category) }
        end
      end

      def average_of(entries)
        values = entries.filter_map { |entry| yield(entry) }
        return nil if values.empty?

        (values.sum(&:to_f) / values.size).round(2)
      end

      def sem_of(entries)
        values = entries.filter_map { |entry| yield(entry) }.map(&:to_f)
        return nil if values.size < 2

        mean = values.sum / values.size
        variance = values.sum { |value| (value - mean)**2 } / (values.size - 1)
        (Math.sqrt(variance / values.size) * 1.96).round(2)
      end

      def proportion_ci95(successes, total)
        return nil if total.zero?

        p = successes.to_f / total
        se = Math.sqrt(p * (1 - p) / total)
        half_width = (1.96 * se * 100).round(1)
        { "half_width_pp" => half_width, "n" => total }
      end

      def csv
        require "csv"
        headers = [ "case_id", "run_index", "source_example", "outcome_expected", "verdict", "overall",
          *Scorer::CATEGORIES, "note", "assistant_response", "tool_sequence", "wall_clock_ms" ]
        CSV.generate do |csv_out|
          csv_out << headers
          @entries.each do |entry|
            result = entry[:result]
            scores = result["scores"] || {}
            csv_out << [
              result["case_id"], result["run_index"], result["source_example"], result["outcome_expected"],
              result["verdict"], result["overall"], *Scorer::CATEGORIES.map { |category| scores[category] },
              result["note"], result.dig("observed", "assistant_response"),
              Array(result.dig("observed", "tool_sequence")).join("+"),
              result.dig("observed", "wall_clock_ms")
            ]
          end
        end
      end

      def tool_stats
        events = @entries.flat_map { |entry| entry[:capture]["recorded_tool_events"] }
        events.group_by { |event| event["tool"] }.sort_by { |tool, _| tool }.map do |tool, grouped|
          durations = grouped.pluck("duration_ms").compact
          {
            "tool" => tool,
            "calls" => grouped.size,
            "errors" => grouped.count { |event| event["error"] },
            "avg_duration_ms" => durations.empty? ? nil : (durations.sum.to_f / durations.size).round
          }
        end
      end

      def critical_failures
        evaluated.reject { |entry| entry[:result]["verdict"] == "PASS" }.map do |entry|
          weak = entry[:result]["scores"].select { |_, score| score && score < 8 }
          {
            "case_id" => entry[:result]["case_id"],
            "run_index" => entry[:result]["run_index"],
            "overall" => entry[:result]["overall"],
            "note" => entry[:result]["note"],
            "weak_categories" => weak
          }
        end
      end

      def markdown
        <<~REPORT
          # Harness Eval Report

          #{meta_lines}

          ## Totals

          - Cases: #{totals['cases']}
          - Executions: #{totals['executions']}
          - Evaluated: #{totals['evaluated']}
          - Infrastructure errors: #{totals['infrastructure_errors']}
          - Pass rate: #{pass_rate}% (#{passes.size}/#{totals['evaluated']}) ±#{totals.dig('pass_rate_ci95', 'half_width_pp') || '—'}pp 95% CI (n=#{totals['evaluated']})
          - Overall average: #{totals['overall_average']} ±#{totals['overall_sem'] || '—'} 95% CI half-width

          ## Consistency

          #{consistency_table}

          ## Category averages

          #{category_table}

          ## Per-case results

          #{per_case_table}

          ## Tool stats

          #{tool_table}

          ## Critical failures

          #{failures_section}
        REPORT
      end

      def meta_lines
        @meta.map { |key, value| "- #{key.tr('_', ' ')}: #{value}" }.join("\n")
      end

      def category_table
        rows = category_averages.map { |category, avg| "| #{category} | #{avg || '—'} |" }
        ([ "| category | avg |", "| --- | --- |" ] + rows).join("\n")
      end

      def per_case_table
        header = "| source | case | expected outcome | #{Scorer::CATEGORIES.map { |c| CATEGORY_HEADERS.fetch(c) }.join(' | ')} | overall | verdict |"
        divider = "| #{'--- | ' * (Scorer::CATEGORIES.size + 5)}"
        rows = @entries.map do |entry|
          result = entry[:result]
          scores = Scorer::CATEGORIES.map { |category| result["scores"].fetch(category) || "—" }
          case_label = result["run_index"] ? "#{result['case_id']} · run #{result['run_index']}" : result["case_id"]
          source = result["source_example"] ? "#{result['source_example']}. #{result['source_title']}" : "—"
          "| #{source} | #{case_label} | #{result['outcome_expected']} | #{scores.join(' | ')} | #{result['overall'] || '—'} | #{result['verdict']} |"
        end
        ([ header, divider ] + rows).join("\n")
      end

      def consistency_table
        rows = @entries.group_by { |entry| entry[:result]["case_id"] }.sort.map do |case_id, grouped|
          valid = grouped.select { |entry| %w[PASS FAIL].include?(entry[:result]["verdict"]) }
          verdicts = valid.map { |entry| entry[:result]["verdict"] }
          agreement = if verdicts.empty?
            "—"
          else
            "#{(verdicts.tally.values.max.to_f / verdicts.size * 100).round(1)}%"
          end
          infra = grouped.count { |entry| entry[:result]["verdict"] == "INFRA_ERROR" }
          "| #{case_id} | #{verdicts.count('PASS')}/#{valid.size} | #{infra} | #{agreement} |"
        end
        ([ "| case | passes | infra | verdict agreement |", "| --- | --- | --- | --- |" ] + rows).join("\n")
      end

      def tool_table
        return "_no tool calls recorded_" if tool_stats.empty?

        header = "| tool | calls | errors | avg ms |"
        divider = "| --- | --- | --- | --- |"
        rows = tool_stats.map do |stats|
          "| #{stats['tool']} | #{stats['calls']} | #{stats['errors']} | #{stats['avg_duration_ms'] || '—'} |"
        end
        ([ header, divider ] + rows).join("\n")
      end

      def failures_section
        failures = critical_failures
        return "_none — all cases passed_" if failures.empty? && infrastructure_errors.empty?

        failed = failures.map do |failure|
          run = failure["run_index"] ? " · run #{failure['run_index']}" : ""
          entry = @entries.find do |candidate|
            candidate[:result]["case_id"] == failure["case_id"] &&
              candidate[:result]["run_index"] == failure["run_index"]
          end
          response = entry&.dig(:result, "observed", "assistant_response").to_s.squish
          response_line = response.present? ? "\n\nAssistant response: #{response}" : ""
          "### #{failure['case_id']}#{run} (overall #{failure['overall']})\n\n#{failure['note']}#{response_line}"
        end.join("\n\n")
        failed + infrastructure_section
      end

      def infrastructure_section
        return "" if infrastructure_errors.empty?

        rows = infrastructure_errors.map do |entry|
          "- #{entry[:result]['case_id']} run #{entry[:result]['run_index']}: #{entry[:result]['note']}"
        end
        "\n\n### Infrastructure errors\n\n#{rows.join("\n")}"
      end
    end
  end
end
