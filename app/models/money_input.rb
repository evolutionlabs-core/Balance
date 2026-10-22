module MoneyInput
  FORMAT = /\A\d+(\.\d{1,2})?\z/

  def self.to_kobo(value)
    raw = value.to_s.strip.delete(",")
    prefix = Currency.prefixes.find { |candidate| raw.start_with?(candidate) }
    raw = raw.delete_prefix(prefix).strip if prefix

    if FORMAT.match?(raw)
      (BigDecimal(raw) * 100).to_i
    end
  end
end
