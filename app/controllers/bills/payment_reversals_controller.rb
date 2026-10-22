class Bills::PaymentReversalsController < ApplicationController
  include BusinessWorkspace

  def create
    bill = current_workspace.bills.find(params[:bill_id])
    payment = bill.payments.find(params[:payment_id])

    if bill.reverse_payment!(payment)
      redirect_to bill_path(bill), notice: "Payment reversed. #{bill.display_name} is open again."
    else
      redirect_to bill_path(bill), alert: bill.errors.full_messages.to_sentence
    end
  end
end
