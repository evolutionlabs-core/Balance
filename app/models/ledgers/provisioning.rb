module Ledgers
  module Provisioning
    extend ActiveSupport::Concern

    def provision_ledger!(template:)
      raise ArgumentError, "Workspace already has a ledger" if ledgers.exists?

      Ledger.transaction do
        ledger = Ledger.create!(workspace: self, name: "General", currency_code: currency_code)
        rows = chart_rows(template)
        validate_chart_rows!(rows, template)
        create_chart_accounts!(ledger, rows)
        ledger
      end
    end

    private
      def chart_rows(template)
        data = YAML.load_file(Rails.root.join("config/charts/#{template}.yml"))
        (data["accounts"] || data[:accounts]).map(&:with_indifferent_access)
      rescue Errno::ENOENT
        raise ArgumentError, "Unknown chart template: #{template}"
      end

      def validate_chart_rows!(rows, template)
        rows.each do |row|
          unless LedgerSubtypes.valid?(row[:subtype])
            raise ArgumentError, "Invalid subtype #{row[:subtype]} for account #{row[:code]} in template #{template}"
          end
        end
      end

      def create_chart_accounts!(ledger, rows)
        rows.each do |row|
          ledger.ledger_accounts.create!(
            code: row[:code],
            name: row[:name],
            base_type: row[:base_type],
            subtype: row[:subtype],
            normal_balance: row[:normal_balance],
            system: row[:system] || false,
            active: true,
            created_by: "system",
            description: nil
          )
        end
      end
  end
end
