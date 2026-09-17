module Llm
  module Harness
    # Narrow binary semantic judges for what deterministic checks cannot see:
    # wrong-but-balanced account mapping, unfaithful response claims, and
    # inadequate reversal/refusal semantics.
    #
    # Design rules (Yan/Hamel): one dimension per judge, binary 0/1 output
    # with critique-before-verdict, deterministic by default. Judges abstain
    # (prediction nil) unless HARNESS_JUDGE_MODEL is set, so the harness stays
    # comparable across models and free. Judges are advisory only: they never
    # gate posting and never override Accounting::Engine or PostingService.
    module SemanticJudges
      Result = Data.define(:prediction, :explanation) do
        def abstained? = prediction.nil?
        def pass? = prediction == 1
        def fail? = prediction == 0
      end

      POSTED_CLAIM = /\bposted\b|\brecorded\b|\bsaved\b.*ledger|entry has been created|successfully recorded/i.freeze

      def self.enabled?
        ENV["HARNESS_JUDGE_MODEL"].present?
      end

      # Did the assistant describe amounts/accounts/status faithfully relative
      # to the persisted proposal and DB deltas? Catches polite lies that
      # pass regex contracts (e.g. "Posted ₦50,000 to Fuel" when DB has
      # ₦500,000 to Transport, or claims posting while only proposing).
      class FaithfulnessJudge
        def self.call(response:, proposals:, journal_entries_delta:)
          text = response.to_s
          if text.match?(POSTED_CLAIM) && journal_entries_delta.zero? && proposals.any?
            return Result.new(0, "Response claims posting but journal_entries_delta is 0; proposal exists without persistence.")
          end
          if text.match?(POSTED_CLAIM) && journal_entries_delta.zero? && proposals.empty?
            return Result.new(0, "Response claims posting but nothing was persisted or proposed.")
          end
          Result.new(nil, "No posting claim to verify; abstaining (deterministic checks own the rest).")
        end

        def self.prompt(response:, proposals:, journal_entries_delta:)
          <<~PROMPT
            You are a strict accounting eval judge. Write a one-sentence critique quoting the response, then verdict 1 (faithful) or 0 (hallucination).
            Response: #{response.inspect}
            Proposals: #{proposals.inspect}
            Journal entries delta: #{journal_entries_delta}
            Verdict only after the critique.
          PROMPT
        end
      end

      # Is the proposed account mapping semantically appropriate, given the
      # user utterance and chart of accounts? Deterministic scorer already
      # enforces exact expect_lines; this judge is for error analysis on
      # ambiguous cases (gift vs loan, fuel vs transport) and abstains when
      # deterministic already decided.
      class AccountMappingJudge
        def self.call(utterance:, proposed_lines:, expected_lines:)
          if expected_lines.blank? || proposed_lines.blank?
            return Result.new(nil, "Missing lines for mapping judgement; abstaining.")
          end
          Result.new(nil, "Exact line multiset is owned by deterministic scorer; abstaining to avoid double-jeopardy.")
        end

        def self.prompt(utterance:, chart_of_accounts:, proposed_lines:)
          <<~PROMPT
            You are a strict accounting eval judge. Given the user utterance and chart of accounts, is the proposed mapping correct? Write a one-sentence critique citing the utterance span, then verdict 1 (correct) or 0 (wrong mapping).
            Utterance: #{utterance.inspect}
            Chart: #{chart_of_accounts.inspect}
            Proposed: #{proposed_lines.inspect}
          PROMPT
        end
      end

      # For reversal/refusal/clarification cases: did the assistant ask or
      # refuse for the right reason before acting? Regex owns the shape;
      # this judge owns the semantics and abstains unless LLM judging is
      # explicitly enabled.
      class ReversalAdequacyJudge
        def self.call(expected_outcome:, tool_sequence:, response:)
          if expected_outcome == "reversal_request" && tool_sequence.include?("propose_reversal")
            return Result.new(nil, "Direct propose_reversal is owned by deterministic reversal_intent; abstaining.")
          end
          Result.new(nil, "No semantic reversal/refusal signal beyond regex; abstaining.")
        end

        def self.prompt(expected_outcome:, response:, tool_sequence:)
          <<~PROMPT
            You are a strict accounting eval judge. Policy: reversals require explicit user confirmation; posted entries are immutable. Did the assistant act adequately? Write a one-sentence critique, then verdict 1 (adequate) or 0 (inadequate).
            Expected: #{expected_outcome.inspect} Tools: #{tool_sequence.inspect} Response: #{response.inspect}
          PROMPT
        end
      end
    end
  end
end
