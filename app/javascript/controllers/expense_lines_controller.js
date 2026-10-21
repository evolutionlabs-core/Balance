import { Controller } from "@hotwired/stimulus"
import { formatAmount, parseAmount } from "lib/money"

export default class extends Controller {
  static targets = ["lines", "template", "row", "amount", "position", "destroy", "total"]

  connect() {
    this.reindex()
    this.recalculate()
  }

  addLine() {
    const index = Date.now()
    this.linesTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replaceAll("__INDEX__", index))
    this.reindex()
  }

  removeLine(event) {
    const row = event.currentTarget.closest("[data-expense-lines-target='row']")
    const destroy = row.querySelector("[data-expense-lines-target='destroy']")

    if (destroy.value === "false" && row.querySelector("input[name$='[id]']")) {
      destroy.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }

    this.reindex()
    this.recalculate()
  }

  recalculate() {
    const total = this.visibleRows.reduce((sum, row) => {
      const input = row.querySelector("[data-expense-lines-target='amount']")
      return sum + parseAmount(input.value)
    }, 0)

    this.totalTarget.textContent = formatAmount(total)
  }

  reindex() {
    this.visibleRows.forEach((row, index) => {
      row.querySelector("[data-expense-lines-target='position']").value = index
    })
  }

  get visibleRows() {
    return this.rowTargets.filter((row) => !row.hidden)
  }
}
