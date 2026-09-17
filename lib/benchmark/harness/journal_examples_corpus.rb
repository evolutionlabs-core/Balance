require "yaml"

module Llm
  module Harness
    class JournalExamplesCorpus
      DOCUMENT_PATH = "lib/benchmark/harness/journal_entry_examples.md"
      TRANSACTIONS_PATH = "lib/benchmark/harness/transactions.yml"

      ACCOUNT_SPECS = {
        "business" => {
          "Cash" => [ "asset", "Bank", "Cash on hand" ],
          "Sales" => [ "income", "Income", "Sales of Product Income" ],
          "Accounts Receivable" => [ "asset", "Accounts receivable (A/R)", "Accounts Receivable (A/R)" ],
          "Inventory" => [ "asset", "Other Current Assets", "Inventory" ],
          "Accounts Payable" => [ "liability", "Accounts payable (A/P)", "Accounts Payable (A/P)" ],
          "Rent Expense" => [ "expense", "Expenses", "Rent or Lease of Buildings" ],
          "Owner's Equity" => [ "equity", "Equity", "Owner's Equity" ],
          "Accounts Payable (USD)" => [ "liability", "Accounts payable (A/P)", "Accounts Payable (A/P)" ],
          "FX Loss" => [ "expense", "Other Expense", "Other Miscellaneous Expense" ]
        },
        "personal" => {
          "Cash" => [ "asset", "Cash & Liquid Assets", "Physical Cash & Digital Wallets" ],
          "Gifts/Personal Expense" => [ "expense", "Personal Outflows", "Other Personal Expense" ],
          "Loans Receivable" => [ "asset", "Investments & Long-Term Assets", "Loans & Receivables" ],
          "Bank Charges" => [ "expense", "Personal Outflows", "Financial Expenses" ],
          "Bank Account" => [ "asset", "Cash & Liquid Assets", "Checking Account" ],
          "Pension (RSA)" => [ "asset", "Investments & Long-Term Assets", "Retirement Accounts" ],
          "Tax Withheld" => [ "expense", "Personal Outflows", "Financial Expenses" ],
          "Salary Income" => [ "income", "Personal Inflows", "Earned Salary & Wages" ],
          "Fuel/Generator Expense" => [ "expense", "Personal Outflows", "Housing & Utilities" ],
          "Transport Expense" => [ "expense", "Personal Outflows", "Transportation" ],
          "Ajo Receivable" => [ "asset", "Investments & Long-Term Assets", "Loans & Receivables" ],
          "Ajo Payout Gain" => [ "income", "Personal Inflows", "Investment Returns" ],
          "Phone (Asset)" => [ "asset", "Investments & Long-Term Assets", "Personal Property & Equipment" ],
          "Accounts Payable (Store)" => [ "liability", "Short-Term Debt", "Short-Term Loans" ],
          "Family Support" => [ "expense", "Personal Outflows", "Other Personal Expense" ],
          "Personal Upkeep" => [ "expense", "Personal Outflows", "Living & Daily Needs" ]
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
          lines = Array(test_case["expect_lines"])
          if lines.any?
            balanced = totals(lines)
            unless balanced["debit_total_kobo"].positive? &&
                balanced["debit_total_kobo"] == balanced["credit_total_kobo"]
              raise "#{test_case.fetch('id')} has an unbalanced source entry"
            end
          end

          catalog = AccountCatalog.for(test_case.fetch("workspace_type"))
          Array(test_case.dig("setup", "account_specs")).each do |spec|
            valid_type = catalog.category_for(spec.fetch("account_type"))&.downcase == spec.fetch("base_type")
            valid_detail = catalog.detail_types_for(spec.fetch("account_type"))&.include?(spec.fetch("detail_type"))
            next if valid_type && valid_detail

            raise "#{test_case.fetch('id')} has invalid taxonomy for #{spec.fetch('name')}"
          end
        end
      end

      def build_case(transaction, examples)
        number = transaction.fetch("source_example")
        source = examples.fetch(number)
        lines = source.fetch("entries").fetch(transaction.fetch("entry_index") - 1)
        workspace_type = transaction.fetch("workspace_type")

        {
          "id" => transaction.fetch("id"),
          "source_example" => number,
          "source_title" => source.fetch("title"),
          "source_entry" => transaction.fetch("entry_index"),
          "workspace_type" => workspace_type,
          "prompt" => transaction.fetch("prompt"),
          "prior_messages" => transaction["prior_messages"],
          "setup" => transaction.fetch("setup", { "account_specs" => account_specs(workspace_type, lines) }),
          "expect_entry_date" => transaction.fetch("expect_entry_date", "today"),
          "expect_lines" => transaction.fetch("expect_lines", lines),
          "expect_amounts" => transaction.fetch("expect_amounts", totals(lines)),
          "expect_accounts" => transaction["expect_accounts"],
          "expect_account_roles" => transaction["expect_account_roles"],
          "safety_case" => transaction["safety_case"],
          "split" => transaction.fetch("split", "dev"),
          "synthetic" => transaction.fetch("synthetic", false),
          "expected" => transaction.fetch("expected", {
            "outcome" => "journal_entry_proposal",
            "tool_sequence" => [ "list_accounts", "propose_entry" ]
          })
        }.compact
      end

      def account_specs(workspace_type, lines)
        lines.map { |line| line.fetch("account_name") }.uniq.map do |name|
          base_type, account_type, detail_type = ACCOUNT_SPECS.fetch(workspace_type).fetch(name)
          { "name" => name, "base_type" => base_type, "account_type" => account_type, "detail_type" => detail_type }
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
