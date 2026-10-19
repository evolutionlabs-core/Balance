module AccountingEngine
  module Builders
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
        AccountingEngine::Command.new(
          ledger: ledger,
          effective_date: effective_date,
          source_type: source_type,
          source_id: source_id,
          action: action,
          description: description,
          metadata: metadata,
          lines: lines,
          reverses_entry: reverses_entry,
          posted_by: Current.user
        )
      end

      private
        attr_reader :workspace, :attributes, :source_id, :description, :metadata

        def source_type
          self.class.name.demodulize
        end

        def ledger
          @ledger ||= workspace.ledger
        end

        def account_for(key)
          ledger.accounts.find_by(key: key) ||
            raise(AccountMissing, "No #{key.titleize} account is provisioned in the #{ledger.name} ledger.")
        end

        def account(id)
          ledger.accounts.find_by(id: id) ||
            raise(AccountMissing, "Account #{id} is not in the #{ledger.name} ledger.")
        end

        def reverses_entry
          nil
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
