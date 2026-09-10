import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["form"]

  async preview(event) {
    event.preventDefault()
    const url = event.currentTarget.href

    for (const form of this.formTargets) {
      if (form.hasAttribute("aria-busy")) {
        await new Promise(resolve => form.addEventListener("turbo:submit-end", resolve, { once: true }))
      }
      if (!form.reportValidity()) return

      const saved = await new Promise(resolve => {
        const action = form.action
        form.addEventListener("turbo:submit-end", event => {
          form.action = action
          resolve(event.detail.success)
        }, { once: true })
        const submission = new URL(action)
        submission.searchParams.set("preview", "true")
        form.action = submission.toString()
        form.requestSubmit()
      })
      if (!saved) return
    }

    Turbo.visit(url)
  }
}
