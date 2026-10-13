module Engine
  module Adapters
    class Base
      def self.call(workspace:, attributes:, source_id:, description: nil, metadata: {})
        new(workspace: workspace, attributes: attributes, source_id: source_id, description: description, metadata: metadata).call
      end

      def initialize(workspace:, attributes:, source_id:, description: nil, metadata: {})
        @workspace = workspace
        @attributes = attributes
        @source_id = source_id
        @description = description
        @metadata = metadata
      end

      def call
        Engine::Command.new(
          ledger: ledger,
          effective_date: effective_date,
          source_type: source_type,
          source_id: source_id,
          action: action,
          description: description,
          metadata: metadata,
          lines: lines
        )
      end

      private
        attr_reader :workspace, :attributes, :source_id, :description, :metadata

        def source_type
          self.class.name.demodulize
        end

        def ledger
          @ledger ||= workspace.ledgers.first ||
            workspace.provision_ledger!(template: workspace.ledger_template)
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

        def receivable_account
          ledger.ledger_accounts.find_by!(subtype: "accounts_receivable")
        rescue ActiveRecord::RecordNotFound
          raise ActiveRecord::RecordNotFound,
            "No Accounts Receivable account is provisioned in the #{ledger.name} ledger."
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
