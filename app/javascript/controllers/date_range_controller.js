import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
  static targets = ["input", "from", "to"]

  connect() {
    const selected = [this.fromTarget.value, this.toTarget.value].filter(Boolean)
    this.picker = flatpickr(this.inputTarget, {
      mode: "range",
      altInput: true,
      altFormat: "M j, Y",
      dateFormat: "Y-m-d",
      defaultDate: selected,
      maxDate: "today",
      allowInput: false,
      onChange: (dates) => this.updateRange(dates)
    })
  }

  disconnect() {
    this.picker?.destroy()
  }

  updateRange(dates) {
    this.fromTarget.value = dates[0] ? this.isoDate(dates[0]) : ""
    this.toTarget.value = dates[1] ? this.isoDate(dates[1]) : ""
    if (dates.length !== 1) this.dispatch("change")
  }

  isoDate(date) {
    return [date.getFullYear(), String(date.getMonth() + 1).padStart(2, "0"), String(date.getDate()).padStart(2, "0")].join("-")
  }
}
