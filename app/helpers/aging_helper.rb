module AgingHelper
  AGING_BUCKETS = {
    current: { label: "Not due", color: "#d4d4d4" },
    days_1_30: { label: "1–30 days", color: "#a3a3a3" },
    days_31_60: { label: "31–60 days", color: "#737373" },
    days_61_90: { label: "61–90 days", color: "#525252" },
    over_90: { label: "90+ days", color: "#262626" }
  }.freeze

  def aging_money(kobo)
    number_to_currency(BigDecimal(kobo) / 100, unit: currency_symbol(current_workspace.currency_code), precision: 2)
  end

  def aging_oldest_bucket(row)
    AGING_BUCKETS.keys.reverse.find { |bucket| row.buckets[bucket].positive? } || :current
  end

  def aging_bucket_label(bucket)
    AGING_BUCKETS.fetch(bucket)[:label]
  end

  def aging_share(amount, total)
    total.positive? ? (amount * 100.0 / total).round(2) : 0
  end
end
