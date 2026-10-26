module IncomeLineChecks
  private
    def income_line_errors(lines)
      if workspace.default_sales_account.nil? && lines.any? { |line| line.account.nil? }
        [ "Choose a default income account in Settings, or pick a service for each line" ]
      else
        lines.each_with_index.filter_map do |line, index|
          if line.account.nil?
            "Line #{index + 1}: #{line.description.presence || "item"} has no income account"
          elsif line.account.base_type != "income"
            "Line #{index + 1}: account #{line.account.name} is not an income account"
          elsif line.account.ledger.workspace_id != workspace_id
            "Line #{index + 1}: account #{line.account.name} belongs to another workspace"
          end
        end
      end
    end
end
