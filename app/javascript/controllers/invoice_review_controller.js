import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "message", "frame", "pdf"]

  select(event) {
    const name = event.currentTarget.dataset.panel

    this.tabTargets.forEach((tab) => tab.setAttribute("aria-selected", tab.dataset.panel === name))
    this.panelTargets.forEach((panel) => { panel.hidden = panel.dataset.panel !== name })

    if (name === "pdf" && !this.pdfTarget.src) this.pdfTarget.src = this.pdfTarget.dataset.src
  }

  preview() {
    const container = this.frameTarget.contentDocument?.getElementById("invoice-message")
    if (!container) return

    container.replaceChildren(...this.paragraphs(this.messageTarget.value))
  }

  paragraphs(text) {
    return text.split(/\n{2,}/).map((block) => {
      const paragraph = document.createElement("p")
      block.split("\n").forEach((line, index) => {
        if (index > 0) paragraph.append(document.createElement("br"))
        paragraph.append(line)
      })
      return paragraph
    })
  }
}
