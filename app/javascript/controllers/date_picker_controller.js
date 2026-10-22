import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"
import { placeBelow } from "lib/floating"

export default class extends Controller {
  static values = { allowFuture: Boolean }

  connect() {
    const dialog = this.element.closest("dialog")

    this.picker = flatpickr(this.element, {
      altInput: true,
      altFormat: "M j, Y",
      dateFormat: "Y-m-d",
      defaultDate: this.element.value || "today",
      maxDate: this.allowFutureValue ? null : "today",
      allowInput: true,
      ...(dialog && {
        appendTo: dialog,
        position: (picker) => placeBelow(picker.calendarContainer, picker.altInput)
      })
    })
  }

  disconnect() {
    this.picker?.destroy()
  }
}
