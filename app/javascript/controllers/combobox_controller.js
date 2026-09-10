import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "menu"]

  disconnect() {
    clearTimeout(this.searchTimeout)
  }

  open() {
    this.menuTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  search() {
    this.open()
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => this.inputTarget.form.requestSubmit(), 150)
  }

  toggle() {
    this.menuTarget.hidden ? this.open() : this.close()
  }

  close() {
    this.menuTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
  }

  closeOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  focusOption(event) {
    event.preventDefault()
    this.open()
    this.menuTarget.querySelector("a, button")?.focus()
  }
}
