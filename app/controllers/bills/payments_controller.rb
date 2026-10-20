class Bills::PaymentsController < ApplicationController
  include BusinessWorkspace

  before_action :set_bill
  before_action :ensure_payable_bill
  before_action :set_payment_accounts

  def new
  end

  def create
    if @bill.record_payment!(
      payment_account_id: payment_params[:payment_account_id],
      paid_on: parsed_paid_on,
      amount_kobo: parsed_amount_kobo
    )
      redirect_out_of_frame bill_path(@bill), notice: "Payment recorded for #{@bill.display_name.downcase_first}."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_bill
      @bill = current_workspace.bills.includes(:vendor, :payments).find(params[:bill_id])
    end

    def ensure_payable_bill
      return if @bill.open? && @bill.balance_due_kobo.positive?

      redirect_to bill_path(@bill), alert: "Only an entered bill with a balance can be paid."
    end

    def set_payment_accounts
      @payment_accounts = current_workspace.payment_accounts
    end

    def payment_params
      params.expect(bill_payment: [ :payment_account_id, :paid_on, :amount ])
    end

    def parsed_paid_on
      Date.parse(payment_params[:paid_on].to_s)
    rescue Date::Error
      nil
    end

    def parsed_amount_kobo
      MoneyInput.to_kobo(payment_params[:amount])
    end
end
