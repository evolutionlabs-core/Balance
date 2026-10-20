class Bills::IssuancesController < ApplicationController
  include BusinessWorkspace

  before_action :set_bill
  before_action :ensure_draft

  def new
  end

  def create
    if @bill.issue!
      redirect_out_of_frame bill_path(@bill), notice: "#{@bill.display_name} entered."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_bill
      @bill = current_workspace.bills.includes(:vendor, bill_lines: :account).find(params[:bill_id])
    end

    def ensure_draft
      return if @bill.draft?

      redirect_to bill_path(@bill), alert: "#{@bill.display_name} has already been entered."
    end
end
