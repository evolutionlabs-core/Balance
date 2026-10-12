module Engine
  module Adapters
    class Base
      def self.call(workspace:, attributes:, source_id:)
        new(workspace: workspace, attributes: attributes, source_id: source_id).call
      end

      def initialize(workspace:, attributes:, source_id:)
        @workspace = workspace
        @attributes = attributes
        @source_id = source_id
      end

      def call
        Engine::Command.new(
          ledger: ledger,
          effective_date: effective_date,
          source_type: source_type,
          source_id: source_id,
          action: action,
          lines: lines
        )
      end

      private
        attr_reader :workspace, :attributes, :source_id

        def source_type
          self.class.name.demodulize
        end

        def ledger
          @ledger ||= workspace.ledgers.first ||
            Ledgers::Provisioner.call(workspace: workspace, template: template)
        end

        def template
          workspace.personal? ? "personal_finance" : "standard_sme"
        end

        def kobo(amount)
          (BigDecimal(amount.to_s) * 100).to_i
        end

        def ledger_account_for(name)
          ledger.ledger_accounts.find_by!(name: name)
        rescue ActiveRecord::RecordNotFound
          raise ActiveRecord::RecordNotFound,
            "No ledger account matches #{name.inspect} in the #{ledger.name} ledger."
        end

        def effective_date
          raise NotImplementedError
        end

        def action
          raise NotImplementedError
        end

        def lines
          raise NotImplementedError
        end
    end
  end
end
