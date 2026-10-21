module AgingHelper
  AGING_BUCKETS = {
    current: { label: "Not due yet", short: "Not due", color: "#0d9488" },
    days_1_30: { label: "1–30 days overdue", short: "1–30 days", color: "#f59e0b" },
    days_31_60: { label: "31–60 days overdue", short: "31–60 days", color: "#ea580c" },
    days_61_90: { label: "61–90 days overdue", short: "61–90 days", color: "#dc2626" },
    over_90: { label: "Over 90 days overdue", short: "90+ days", color: "#9f1239" }
  }.freeze

  def aging_money(kobo)
    number_to_currency(BigDecimal(kobo) / 100, unit: currency_symbol(current_workspace.currency_code), precision: 2)
  end

  def aging_share(amount, total)
    total.positive? ? (amount * 100.0 / total).round(2) : 0
  end
end
