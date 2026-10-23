import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "subtype"]
  static values = { map: Object }

  filter() {
    const subtypes = this.mapValue[this.typeTarget.value] || []
    const current = this.subtypeTarget.value
    const prompt = document.createElement("option")
    prompt.value = ""
    prompt.textContent = this.typeTarget.value ? "Select subtype" : "Select a type first"

    const options = subtypes.map(([label, value]) => {
      const option = document.createElement("option")
      option.value = value
      option.textContent = label
      option.selected = value === current
      return option
    })

    this.subtypeTarget.replaceChildren(prompt, ...options)
    this.subtypeTarget.dispatchEvent(new Event("select-menu:refresh", { bubbles: true }))
  }
}
