const amountFormat = new Intl.NumberFormat("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })

export function parseAmount(value) {
  const amount = Number.parseFloat(String(value ?? "").replaceAll(",", ""))
  return Number.isFinite(amount) ? amount : 0
}

export function formatAmount(amount) {
  return amountFormat.format(amount)
}
