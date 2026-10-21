class Expenses::VoidsController < ApplicationController
  before_action :set_expense
  before_action :ensure_voidable

  def new
  end

  def create
    if @expense.void!
      redirect_out_of_frame expense_path(@expense)
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_expense
      @expense = current_workspace.expenses.includes(:journal_entry, expense_lines: :account).find(params[:expense_id])
    end

    def ensure_voidable
      return if @expense.voidable?

      redirect_to expense_path(@expense), alert: "This expense cannot be voided."
    end
end
