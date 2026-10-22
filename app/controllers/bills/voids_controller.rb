class Bills::VoidsController < ApplicationController
  include BusinessWorkspace

  before_action :set_bill
  before_action :ensure_voidable

  def new
  end

  def create
    if @bill.void!
      redirect_out_of_frame bill_path(@bill), notice: "#{@bill.display_name} voided."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_bill
      @bill = current_workspace.bills.includes(:vendor, :payments, :bill_lines).find(params[:bill_id])
    end

    def ensure_voidable
      return if @bill.may_mark_voided?

      redirect_to bill_path(@bill), alert: "#{@bill.display_name} cannot be voided."
    end
end
