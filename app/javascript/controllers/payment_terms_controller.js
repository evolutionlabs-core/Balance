import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["terms", "issueDate", "dueDate"]
  static values = { days: Object, issueDate: String }

  apply() {
    const days = this.daysValue[this.termsTarget.value]
    const issued = this.issuedOn()
    if (days === undefined || !issued) return

    const due = new Date(issued)
    due.setDate(due.getDate() + days)
    this.dueDateTarget._flatpickr?.setDate(due, false)
  }

  markCustom() {
    const days = this.daysValue[this.termsTarget.value]
    if (days === undefined) return

    const issued = this.issuedOn()
    const due = this.dueDateTarget._flatpickr?.selectedDates[0]
    if (issued && due && Math.round((due - issued) / 86400000) === days) return

    this.termsTarget.value = "custom"
    this.termsTarget.dispatchEvent(new Event("select-menu:refresh", { bubbles: true }))
  }

  issuedOn() {
    if (this.hasIssueDateTarget) return this.issueDateTarget._flatpickr?.selectedDates[0]
    if (!this.issueDateValue) return undefined

    const [year, month, day] = this.issueDateValue.split("-").map(Number)
    return new Date(year, month - 1, day)
  }
}
