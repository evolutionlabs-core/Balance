module Ledgers
  class Provisioner
    def self.call(workspace:, template:)
      new(workspace: workspace, template: template).call
    end

    def initialize(workspace:, template:)
      @workspace = workspace
      @template = template
    end

    def call
      raise ArgumentError, "Workspace already has a ledger" if @workspace.ledgers.exists?

      Ledger.transaction do
        ledger = Ledger.create!(workspace: @workspace, name: "General", currency_code: @workspace.currency_code)
        rows = load_template_rows!
        validate_rows!(rows)
        create_template_accounts!(ledger, rows)
        ledger
      end
    end

    private
      def load_template_rows!
        path = Rails.root.join("config/charts/#{@template}.yml")
        data = begin
          YAML.load_file(path)
        rescue Errno::ENOENT
          raise ArgumentError, "Unknown chart template: #{@template}"
        end
        rows = data["accounts"] || data[:accounts]
        rows.map(&:with_indifferent_access)
      end

      def validate_rows!(rows)
        rows.each do |row|
          unless LedgerSubtypes.valid?(row[:subtype])
            raise ArgumentError, "Invalid subtype #{row[:subtype]} for account #{row[:code]} in template #{@template}"
          end
        end
      end

      def create_template_accounts!(ledger, rows)
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
