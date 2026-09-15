import { Controller } from "@hotwired/stimulus"

const MARGIN = 8

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
    const rect = this.buttonTarget.getBoundingClientRect()
    const menu = this.menuTarget
    this.buttonTarget.setAttribute("aria-expanded", "true")
    if (this.matchTriggerWidthValue) menu.style.width = `${rect.width}px`
    menu.style.position = "fixed"
    menu.style.visibility = "hidden"
    menu.classList.remove("hidden")

    menu.style.top = `${rect.bottom + 4}px`
    menu.style.left = `${rect.right - menu.offsetWidth}px`
    this.nudgeIntoView()

    menu.style.visibility = ""

    this.outsideHandler = (event) => {
      if (!this.element.contains(event.target) && !this.menuTarget.contains(event.target)) this.close()
    }
    this.dismissHandler = () => this.close()
    document.addEventListener("click", this.outsideHandler)
    window.addEventListener("scroll", this.dismissHandler, true)
    window.addEventListener("resize", this.dismissHandler)
  }

  nudgeIntoView() {
    const menu = this.menuTarget
    const box = menu.getBoundingClientRect()

    const overflowRight = box.right - (window.innerWidth - MARGIN)
    const overflowLeft = MARGIN - box.left
    const shiftX = overflowRight > 0 ? -overflowRight : Math.max(0, overflowLeft)
    if (shiftX) menu.style.left = `${parseFloat(menu.style.left) + shiftX}px`

    const overflowBottom = box.bottom - (window.innerHeight - MARGIN)
    if (overflowBottom > 0) {
      const flipped = parseFloat(menu.style.top) - box.height - this.buttonTarget.getBoundingClientRect().height - 8
      menu.style.top = `${Math.max(MARGIN, flipped)}px`
    }
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
