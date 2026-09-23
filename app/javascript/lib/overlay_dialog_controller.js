import { Controller } from "@hotwired/stimulus"
import { acquireOverlay, releaseOverlay } from "lib/overlay"

export default class extends Controller {
  static targets = ["backdrop", "panel"]
  static values = { duration: { type: Number, default: 200 } }

  connect() {
    this.returnFocusTo = document.activeElement
    this.element.showModal()
    acquireOverlay(this)
    this.showFrame = requestAnimationFrame(() => this.show())
  }

  disconnect() {
    cancelAnimationFrame(this.showFrame)
    clearTimeout(this.closeTimeout)
    releaseOverlay(this)
  }

  show() {
    this.backdropTarget.classList.replace("opacity-0", "opacity-100")
    this.panelTarget.classList.remove(...this.transitionClasses)
  }

  close(event) {
    event?.preventDefault()
    if (this.closing) return

    this.closing = true
    this.backdropTarget.classList.replace("opacity-100", "opacity-0")
    this.panelTarget.classList.add(...this.transitionClasses)
    this.closeTimeout = setTimeout(() => this.remove(), this.closeDelay)
  }

  clickOutside(event) {
    if (event.target === this.backdropTarget) this.close(event)
  }

  keydown(event) {
    if (event.key === "Escape") this.close(event)
  }

  remove() {
    this.element.close()
    document.getElementById("modal")?.replaceChildren()
    if (this.returnFocusTo?.isConnected) this.returnFocusTo.focus()
  }

  get closeDelay() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches ? 0 : this.durationValue
  }
}
