import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { formatAmount, parseAmount } from "lib/money"

export default class extends Controller {
  static targets = ["form", "amount", "subtotal", "total", "discount", "discountValue", "discountType"]
  static values = { currency: String }

  calculateTotals() {
    const subtotal = this.amountTargets.reduce((sum, input) => sum + parseAmount(input.value), 0)
    const discount = this.discountFor(subtotal)

    this.subtotalTargets.forEach((output) => { output.textContent = this.format(subtotal) })
    this.discountTargets.forEach((output) => { output.textContent = discount > 0 ? `−${this.format(discount)}` : "—" })
    this.totalTargets.forEach((output) => { output.textContent = this.format(subtotal - discount) })
  }

  discountFor(subtotal) {
    if (!this.hasDiscountValueTarget) return 0

    const value = parseAmount(this.discountValueTarget.value)
    const discount = this.discountTypeTarget.value === "percent" ? Math.round(subtotal * value) / 100 : value
    return discount > 0 && discount < subtotal ? discount : 0
  }

  format(amount) {
    return `${this.currencyValue} ${formatAmount(amount)}`
  }

  async saveAndShow(event) {
    event.preventDefault()
    const url = event.currentTarget.href

    for (const form of this.formTargets) {
      if (form.hasAttribute("aria-busy")) {
        await new Promise(resolve => form.addEventListener("turbo:submit-end", resolve, { once: true }))
      }
      if (!form.reportValidity()) return

      const saved = await new Promise(resolve => {
        const action = form.action
        const method = form.querySelector("input[name='_method']")
        const originalMethod = method?.value
        form.addEventListener("turbo:submit-end", event => {
          form.action = action
          if (method) method.value = originalMethod
          resolve(event.detail.success)
        }, { once: true })
        const submission = new URL(form.dataset.saveUrl || action, window.location.origin)
        form.action = submission.toString()
        if (method && form.dataset.saveMethod) method.value = form.dataset.saveMethod
        form.requestSubmit()
      })
      if (!saved) return
    }

    Turbo.visit(url)
  }
}
