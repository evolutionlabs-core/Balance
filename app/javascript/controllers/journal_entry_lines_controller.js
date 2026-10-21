import { Controller } from "@hotwired/stimulus"
import { formatAmount, parseAmount } from "lib/money"
import { appendRow, removeRow, visibleRows } from "lib/line_rows"

export default class extends Controller {
  static targets = ["lines", "template", "row", "account", "debit", "credit", "debitTotal", "creditTotal", "difference", "status", "submit", "draftButton"]

  connect() {
    this.recalculate()
  }

  addLine() {
    appendRow(this.linesTarget, this.templateTarget)
    this.recalculate()
  }

  removeLine(event) {
    const row = event.currentTarget.closest("[data-journal-entry-lines-target='row']")
    if (row.dataset.protected === "true") return

    removeRow(row)
    this.recalculate()
  }

  amountChanged(event) {
    const row = event.target.closest("[data-journal-entry-lines-target='row']")
    const counterpart = event.target.matches("[data-journal-entry-lines-target='debit']")
      ? row.querySelector("[data-journal-entry-lines-target='credit']")
      : row.querySelector("[data-journal-entry-lines-target='debit']")

    if (this.amount(event.target) > 0) counterpart.value = ""
    this.recalculate()
  }

  recalculate() {
    const activeRows = visibleRows(this.rowTargets)
    const debitTotal = activeRows.reduce((total, row) => total + this.amount(row.querySelector("[data-journal-entry-lines-target='debit']")), 0)
    const creditTotal = activeRows.reduce((total, row) => total + this.amount(row.querySelector("[data-journal-entry-lines-target='credit']")), 0)
    const difference = debitTotal - creditTotal
    const complete = activeRows.length >= 2 && activeRows.every((row) => this.rowComplete(row))
    const balanced = debitTotal > 0 && Math.abs(difference) < 0.005

    this.debitTotalTarget.textContent = formatAmount(debitTotal)
    this.creditTotalTarget.textContent = formatAmount(creditTotal)
    this.differenceTarget.textContent = formatAmount(Math.abs(difference))
    this.differenceTarget.classList.toggle("text-red-600", Math.abs(difference) >= 0.005)
    this.submitTarget.disabled = !(complete && balanced)
    this.statusTarget.textContent = complete && balanced
      ? "Balanced and ready to review."
      : "Choose an account and enter either a debit or credit on every line; totals must balance."
    this.statusTarget.classList.toggle("text-emerald-700", complete && balanced)
  }

  validate(event) {
    if (this.hasDraftButtonTarget && event.submitter === this.draftButtonTarget) return

    this.recalculate()
    if (!this.submitTarget.disabled) return

    event.preventDefault()
    this.statusTarget.scrollIntoView({ behavior: "smooth", block: "nearest" })
  }

  rowComplete(row) {
    const account = row.querySelector("[data-journal-entry-lines-target='account']")
    const debit = this.amount(row.querySelector("[data-journal-entry-lines-target='debit']"))
    const credit = this.amount(row.querySelector("[data-journal-entry-lines-target='credit']"))
    return account.value && ((debit > 0) !== (credit > 0))
  }

  amount(input) {
    return parseAmount(input?.value)
  }
}
