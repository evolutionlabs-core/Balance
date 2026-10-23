import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  clean() {
    const cleaned = this.element.value.replace(/[^\d\s()+.-]/g, "")
    if (cleaned === this.element.value) return

    const caret = this.element.selectionStart - (this.element.value.length - cleaned.length)
    this.element.value = cleaned
    this.element.setSelectionRange(caret, caret)
  }
}
