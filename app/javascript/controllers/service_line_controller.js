import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "service", "description", "quantity", "rate", "amount" ]

  applyDefaults() {
    const option = this.serviceTarget.selectedOptions[0]

    if (!option.value) return
    if (!this.quantityTarget.value) this.quantityTarget.value = "1"

    if (!this.descriptionTarget.value) this.descriptionTarget.value = option.dataset.description || ""
    if (!this.rateTarget.value && option.dataset.rate) {
      this.rateTarget.value = option.dataset.rate
    }
    this.calculateAmount()
    this.rateTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  calculateAmount() {
    const quantity = Number.parseFloat(this.quantityTarget.value) || 0
    const rate = Number.parseFloat(this.rateTarget.value) || 0

    this.amountTarget.value = (quantity * rate).toFixed(2)
    this.amountTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
