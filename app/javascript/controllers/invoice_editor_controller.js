import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["form"]

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
