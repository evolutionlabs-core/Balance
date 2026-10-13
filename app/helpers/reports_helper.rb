module ReportsHelper
  def statement_amount(balance, normal_balance)
    naira(normal_balance == "debit" ? balance : -balance)
  end
end
