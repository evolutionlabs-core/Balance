module MoneyInput
  FORMAT = /\A\d+(\.\d{1,2})?\z/

  def self.to_kobo(value)
    raw = value.to_s.strip.delete(",").delete_prefix("₦").delete_prefix("NGN").strip

    if FORMAT.match?(raw)
      (BigDecimal(raw) * 100).to_i
    end
  end
end
