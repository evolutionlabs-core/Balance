import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { formatAmount, parseAmount } from "lib/money"

export default class extends Controller {
  static targets = ["form", "amount", "total"]
  static values = { currency: String }

  calculateTotals() {
    const total = this.amountTargets.reduce((sum, input) => sum + parseAmount(input.value), 0)
    const formatted = `${this.currencyValue} ${formatAmount(total)}`

    this.totalTargets.forEach((output) => { output.textContent = formatted })
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
