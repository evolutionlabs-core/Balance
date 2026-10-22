module LineItemsHelper
  def money_input_value(amount)
    format("%.2f", amount) if amount
  end

  def discount_input_value(document)
    return if document.discount_value.nil?

    document.discount_type == "amount" ? money_input_value(document.discount_value) : document.discount_value.to_s("F").delete_suffix(".0")
  end
end
