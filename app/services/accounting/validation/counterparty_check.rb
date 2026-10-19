module Accounting::Validation
  module CounterpartyCheck
    SUBLEDGERS = {
      "customer" => "invoices and invoice payments",
      "vendor" => "bills and bill payments"
    }.freeze

    def self.call(command)
      command.lines.each_with_index.flat_map do |line, index|
        line_errors(line, "Line #{index + 1}", command.ledger)
      end
    end

    class << self
      private
        def line_errors(line, label, ledger)
          control = line.account.control_counterparty

          [].tap do |errors|
            if control && counterparty(line, control).nil?
              errors << error("#{label}: #{line.account.name} is a control account; record it through #{SUBLEDGERS.fetch(control)}")
            end

            %w[customer vendor].each do |kind|
              party = counterparty(line, kind)
              next if party.nil?

              if kind != control
                errors << error("#{label}: a #{kind} can only be named on a #{kind == "customer" ? "receivables" : "payables"} account")
              elsif party.workspace_id != ledger.workspace_id
                errors << error("#{label}: the #{kind} belongs to another workspace")
              end
            end
          end
        end

        def counterparty(line, kind)
          line.public_send(kind)
        end

        def error(message)
          Error.new(:counterparty, message)
        end
    end
  end
end
