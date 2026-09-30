class Accounting::InvoiceAccountResolver
  Error = Data.define(:code, :message, :invoice_line_id)
  Result = Data.define(:receivable_account_id, :income_account_ids, :errors) do
    def success? = errors.empty?
  end

  def resolve(invoice)
    errors = []
    receivable_account = invoice.workspace.accounts.find_by(role: "receivable")
    unless receivable_account
      errors << Error.new(
        code: :receivable_account_missing,
        message: "Accounts Receivable is not configured for this workspace",
        invoice_line_id: nil
      )
    end

    income_account_ids = invoice.invoice_lines.each_with_object({}) do |line, resolved|
      account = income_account_for(line, invoice.workspace)
      if account.blank?
        errors << Error.new(
          code: :income_account_missing,
          message: "Invoice line #{line.position + 1} has no income account; configure its service or the workspace default sales account",
          invoice_line_id: line.id
        )
      elsif account.workspace_id != invoice.workspace_id || account.base_type != "income"
        errors << Error.new(
          code: :income_account_invalid,
          message: "Invoice line #{line.position + 1} income account must be an income account in this workspace",
          invoice_line_id: line.id
        )
      else
        resolved[line.id] = account.id
      end
    end

    Result.new(
      receivable_account_id: receivable_account&.id,
      income_account_ids: income_account_ids.freeze,
      errors: errors.freeze
    )
  end

  private
    def income_account_for(line, workspace)
      if line.account_id.present?
        line.account
      else
        line.service&.income_account || workspace.default_sales_account
      end
    end
end
