import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["form"]

  async preview(event) {
    event.preventDefault()
    const url = event.currentTarget.href

    for (const form of this.formTargets) {
      if (!form.reportValidity()) return

      const saved = await new Promise(resolve => {
        form.addEventListener("turbo:submit-end", event => resolve(event.detail.success), { once: true })
        form.requestSubmit()
      })
      if (!saved) return
    }

    Turbo.visit(url)
  }
}
