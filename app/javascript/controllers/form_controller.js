import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["clear"]
  static values = { delay: { type: Number, default: 300 } }

  disconnect() {
    clearTimeout(this.timeout)
  }

  submit(event) {
    const form = event.target.form || this.element
    clearTimeout(this.timeout)
    if (form.checkValidity()) form.requestSubmit()
    this.toggleClear()
  }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
    this.toggleClear()
  }

  toggleClear() {
    if (!this.hasClearTarget) return

    const active = [...new FormData(this.element)].some(([name, value]) => !["archived", "range"].includes(name) && value !== "" && value !== "all")
    this.clearTarget.hidden = !active
  }
}
