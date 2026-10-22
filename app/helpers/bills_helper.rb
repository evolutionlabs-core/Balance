module BillsHelper
  def bill_status_badge(bill)
    if bill.paid?
      status_badge("Paid", tone: :success)
    elsif bill.open? && bill.balance_due_kobo < bill.total_kobo
      status_badge("Partially paid", tone: :warning)
    elsif bill.open?
      status_badge("Open", tone: :success)
    elsif bill.voided?
      status_badge("Voided", tone: :warning)
    else
      status_badge("Draft", tone: :warning)
    end
  end

  def bill_table_columns
    [
      { label: "Vendor" }, { label: "Bill" }, { label: "Total", align: :right }, { label: "Balance due", align: :right },
      { label: "Status" }, { label: "Due date" }
    ]
  end

  def bill_line_account_options(workspace, selected = nil)
    accounts = workspace.accounts.active.ordered.select { |account| BillLine.eligible_account?(account) }
    expense_account_options(accounts, selected)
  end
end
