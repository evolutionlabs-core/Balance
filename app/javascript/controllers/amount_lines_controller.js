import { Controller } from "@hotwired/stimulus"
import { formatAmount, parseAmount } from "lib/money"
import { appendRow, removeRow, visibleRows } from "lib/line_rows"

export default class extends Controller {
  static targets = ["lines", "template", "row", "amount", "position", "total"]

  connect() {
    this.reindex()
    this.recalculate()
  }

  addLine() {
    appendRow(this.linesTarget, this.templateTarget)
    this.reindex()
  }

  removeLine(event) {
    removeRow(event.currentTarget.closest("[data-amount-lines-target='row']"))
    this.reindex()
    this.recalculate()
  }

  recalculate() {
    const total = this.activeRows.reduce((sum, row) => sum + parseAmount(this.field(row, "amount").value), 0)
    this.totalTarget.textContent = formatAmount(total)
  }

  reindex() {
    this.activeRows.forEach((row, index) => { this.field(row, "position").value = index })
  }

  field(row, name) {
    return row.querySelector(`[data-amount-lines-target='${name}']`)
  }

  get activeRows() {
    return visibleRows(this.rowTargets)
  }
}
