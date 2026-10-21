import { Controller } from "@hotwired/stimulus"
import { placeBelow } from "lib/floating"

export default class extends Controller {
  static targets = ["button", "menu"]
  static values = { matchTriggerWidth: Boolean }

  connect() {
    document.addEventListener("overlay:opened", this.dismissForOverlay)
  }

  toggle(event) {
    event.stopPropagation()
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  isOpen() {
    return this.hasMenuTarget && !this.menuTarget.classList.contains("hidden")
  }

  dismiss(event) {
    if (event.key === "Escape" && this.isOpen()) {
      event.preventDefault()
      event.stopPropagation()
      this.close()
      this.buttonTarget.focus()
    }
  }

  open() {
    const menu = this.menuTarget
    this.buttonTarget.setAttribute("aria-expanded", "true")
    if (this.matchTriggerWidthValue) menu.style.width = `${this.buttonTarget.getBoundingClientRect().width}px`
    menu.style.visibility = "hidden"
    menu.classList.remove("hidden")
    placeBelow(menu, this.buttonTarget, { align: "end" })
    menu.style.visibility = ""

    this.outsideHandler = (event) => {
      if (!this.element.contains(event.target) && !this.menuTarget.contains(event.target)) this.close()
    }
    this.dismissHandler = () => this.close()
    document.addEventListener("click", this.outsideHandler)
    window.addEventListener("scroll", this.dismissHandler, true)
    window.addEventListener("resize", this.dismissHandler)
  }

  close() {
    if (this.hasMenuTarget) this.menuTarget.classList.add("hidden")
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "false")
    if (this.outsideHandler) document.removeEventListener("click", this.outsideHandler)
    if (this.dismissHandler) {
      window.removeEventListener("scroll", this.dismissHandler, true)
      window.removeEventListener("resize", this.dismissHandler)
    }
  }

  disconnect() {
    document.removeEventListener("overlay:opened", this.dismissForOverlay)
    this.close()
  }

  dismissForOverlay = () => this.close()
}
