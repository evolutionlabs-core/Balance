module BankTransactionsHelper
  def bank_transaction_date(transaction)
    Time.iso8601(transaction.fetch("booked_at")).to_date.strftime("%b %-d, %Y")
  end

  def bank_transaction_amount(transaction)
    amount = transaction.fetch("amount_minor")
    sign = amount.negative? ? "−" : "+"

    "#{sign}#{money(amount.abs, transaction.fetch("currency"))}"
  end
end
