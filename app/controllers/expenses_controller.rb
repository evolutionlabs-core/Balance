class ExpensesController < ApplicationController
  before_action :set_expense, only: %i[show]

  def index
    @expenses = current_workspace.expenses
      .includes(:payment_account, expense_lines: :account)
      .order(payment_date: :desc, id: :desc)
  end

  def new
    @expense = current_workspace.expenses.build(payment_date: Date.current)
    @expense.expense_lines.build(position: 0)
  end

  def create
    result = Expenses::Creator.call(workspace: current_workspace, attributes: expense_params)

    if result.success?
      redirect_to expense_path(result.expense)
    else
      @expense = result.expense
      render :new, status: :unprocessable_content
    end
  end

  def show
    @ledger_entry = @expense.ledger_entry
  end

  private
    def set_expense
      @expense = current_workspace.expenses
        .includes(:payment_account, expense_lines: :account, ledger_entry: { ledger_lines: :ledger_account })
        .find(params[:id])
    end

    def expense_params
      params.expect(expense: [
        :payment_date, :payment_account_id, :memo,
        expense_lines_attributes: [ [ :id, :account_id, :description, :amount, :position, :_destroy ] ]
      ])
    end
end
