require "yaml"

module Llm
  module Harness
    class JournalExamplesCorpus
      DOCUMENT_PATH = "lib/benchmark/harness/journal_entry_examples.md"
      TRANSACTIONS_PATH = "lib/benchmark/harness/transactions.yml"

      # The example document keeps its historical account names; every name maps
      # onto one chart row [base_type, subtype, name] of the workspace's chart.
      # Names are quoted, not %w[], because chart names contain spaces.
      CHART_ACCOUNTS = {
        "business" => {
          "Cash" => [ "asset", "cash", "Cash" ],
          "Sales" => [ "income", "operating", "Sales" ],
          "Accounts Receivable" => [ "asset", "accounts_receivable", "Accounts Receivable" ],
          "Inventory" => [ "asset", "inventory", "Inventory" ],
          "Accounts Payable" => [ "liability", "accounts_payable", "Accounts Payable" ],
          "Rent Expense" => [ "expense", "rent", "Rent" ],
          "Owner's Equity" => [ "equity", "owner_equity", "Owner Contributions" ],
          "Accounts Payable (USD)" => [ "liability", "accounts_payable", "Accounts Payable" ],
          "FX Loss" => [ "expense", "other_expense", "Other Expense" ]
        },
        "personal" => {
          "Cash" => [ "asset", "cash", "Cash" ],
          "Gifts/Personal Expense" => [ "expense", "other_expense", "Other Expense" ],
          "Loans Receivable" => [ "asset", "investment", "Investments" ],
          "Bank Charges" => [ "expense", "other_expense", "Other Expense" ],
          "Bank Account" => [ "asset", "cash", "Checking Account" ],
          "Pension (RSA)" => [ "asset", "investment", "Investments" ],
          "Tax Withheld" => [ "expense", "other_expense", "Other Expense" ],
          "Salary Income" => [ "income", "salary", "Salary" ],
          "Fuel/Generator Expense" => [ "expense", "other_expense", "Other Expense" ],
          "Transport Expense" => [ "expense", "other_expense", "Other Expense" ],
          "Ajo Receivable" => [ "asset", "investment", "Investments" ],
          "Ajo Payout Gain" => [ "income", "other", "Other Income" ],
          "Phone (Asset)" => [ "asset", "investment", "Investments" ],
          "Accounts Payable (Store)" => [ "liability", "credit_card", "Credit Card" ],
          "Family Support" => [ "expense", "other_expense", "Other Expense" ],
          "Personal Upkeep" => [ "expense", "groceries", "Groceries" ]
        }
      }.freeze

      def self.load!
        new.load!
      end

      def load!
        transactions = YAML.safe_load(Rails.root.join(TRANSACTIONS_PATH).read)
        examples = parse_document
        validate_coverage!(transactions, examples)
        cases = transactions.map { |transaction| build_case(transaction, examples) }
        validate_cases!(cases)
        cases
      end

      private

      def parse_document
        examples = Hash.new { |hash, key| hash[key] = { "title" => nil, "entries" => [] } }
        number = nil
        table = nil

        Rails.root.join(DOCUMENT_PATH).each_line do |line|
          if (heading = line.match(/^## (\d+)\. (.+)$/))
            finish_table(examples, number, table)
            number = heading[1].to_i
            examples[number]["title"] = heading[2].strip
            table = nil
          elsif line.start_with?("| Base Type |")
            finish_table(examples, number, table)
            table = []
          elsif table && line.start_with?("|") && !line.match?(/^\|[-|]+\|$/)
            cells = line.strip.delete_prefix("|").delete_suffix("|").split("|", -1).map(&:strip)
            next if cells.first == "Base Type"

            base_type, account, debit, credit = cells.first(4)
            side, amount = debit.present? ? [ "debit", debit ] : [ "credit", credit ]
            table << {
              "base_type" => base_type.downcase,
              "account_name" => account,
              "side" => side,
              "amount_kobo" => Integer(amount.delete(",")) * 100
            }
          elsif table && line.strip.empty?
            finish_table(examples, number, table)
            table = nil
          end
        end
        finish_table(examples, number, table)
        examples
      end

      def finish_table(examples, number, table)
        examples[number]["entries"] << table if number && table.present?
      end

      def validate_coverage!(transactions, examples)
        duplicate_ids = transactions.pluck("id").tally.select { |_, count| count > 1 }.keys
        raise "Duplicate harness transaction IDs: #{duplicate_ids.join(', ')}" if duplicate_ids.any?

        configured = transactions.group_by { |transaction| transaction.fetch("source_example") }
        missing = (1..17).to_a - configured.keys
        raise "Harness transactions are missing journal examples: #{missing.join(', ')}" if missing.any?

        configured.each do |number, cases|
          expected_indices = (1..examples.fetch(number).fetch("entries").size).to_a
          actual_indices = cases.pluck("entry_index").sort
          next if actual_indices == expected_indices

          raise "Example #{number} must configure entries #{expected_indices.inspect}; got #{actual_indices.inspect}"
        end
      end

      def validate_cases!(cases)
        cases.each do |test_case|
          lines = test_case.fetch("expect_lines")
          totals = totals(lines)
          unless totals["debit_total_kobo"].positive? &&
              totals["debit_total_kobo"] == totals["credit_total_kobo"]
            raise "#{test_case.fetch('id')} has an unbalanced source entry"
          end

          chart = chart_for(test_case.fetch("workspace_type"))
          test_case.dig("setup", "account_specs").each do |spec|
            row = chart.find { |account| account["name"] == spec["name"] }
            next if row && row["base_type"] == spec["base_type"] && row["subtype"] == spec["subtype"]

            raise "#{test_case.fetch('id')} maps to an unknown chart account: #{spec.fetch('name')}"
          end
        end
      end

      def chart_for(workspace_type)
        ChartCatalog.accounts_for(workspace_type).map(&:with_indifferent_access)
      end

      def build_case(transaction, examples)
        number = transaction.fetch("source_example")
        source = examples.fetch(number)
        workspace_type = transaction.fetch("workspace_type")
        lines = source.fetch("entries").fetch(transaction.fetch("entry_index") - 1).map { |line| chart_line(line, workspace_type) }

        {
          "id" => transaction.fetch("id"),
          "source_example" => number,
          "source_title" => source.fetch("title"),
          "source_entry" => transaction.fetch("entry_index"),
          "workspace_type" => workspace_type,
          "prompt" => transaction.fetch("prompt"),
          "prior_messages" => transaction["prior_messages"],
          "setup" => { "account_specs" => account_specs(workspace_type, lines) },
          "expect_entry_date" => "today",
          "expect_lines" => lines,
          "expect_amounts" => totals(lines),
          "expected" => {
            "outcome" => "entry_proposal",
            "tool_sequence" => [ "list_accounts", "propose_entry" ]
          }
        }
      end

      def chart_line(line, workspace_type)
        base_type, subtype, name = CHART_ACCOUNTS.fetch(workspace_type).fetch(line.fetch("account_name"))
        {
          "base_type" => base_type,
          "subtype" => subtype,
          "account_name" => name,
          "side" => line.fetch("side"),
          "amount_kobo" => line.fetch("amount_kobo")
        }
      end

      def account_specs(workspace_type, lines)
        lines.uniq { |line| line.slice("account_name") }.map do |line|
          {
            "name" => line.fetch("account_name"),
            "base_type" => line.fetch("base_type"),
            "subtype" => line.fetch("subtype")
          }
        end
      end

      def totals(lines)
        {
          "debit_total_kobo" => lines.select { |line| line["side"] == "debit" }.sum { |line| line["amount_kobo"] },
          "credit_total_kobo" => lines.select { |line| line["side"] == "credit" }.sum { |line| line["amount_kobo"] }
        }
      end
    end
  end
end
