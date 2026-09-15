class ExpensesController < ApplicationController
  before_action :set_expense, only: %i[show edit update]
  before_action :require_draft_expense, only: %i[edit update]

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
    @expense = current_workspace.expenses.build(expense_params)

    if @expense.save
      redirect_to expense_path(@expense)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      redirect_to expense_path(@expense)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def show
    @journal_entry = @expense.posted? ? @expense.journal_entry : @expense.journal_entry_draft
    @engine_result = Accounting::Engine.check(@journal_entry.journal_entry_lines)
    @possible_duplicates = @expense.possible_duplicates.limit(5)
    @can_post = @expense.draft? && @expense.valid? && @journal_entry.valid?
  end

  private
    def set_expense
      @expense = current_workspace.expenses
        .includes(:payment_account, expense_lines: :account)
        .find(params[:id])
    end

    def require_draft_expense
      raise ActiveRecord::RecordNotFound unless @expense.draft?
    end

    def expense_params
      params.expect(expense: [
        :payment_date, :payment_account_id, :memo,
        expense_lines_attributes: [ [ :id, :account_id, :description, :amount, :position, :_destroy ] ]
      ])
    end
end
