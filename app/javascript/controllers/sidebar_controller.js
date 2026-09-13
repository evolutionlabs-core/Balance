import { Controller } from "@hotwired/stimulus"

const COLLAPSED_KEY = "balance:sidebar-collapsed"

export default class extends Controller {
  static targets = ["panel", "expanded", "collapsed", "navLink", "identityButton"]

  connect() {
    this.panelTarget.classList.remove("transition-[width]", "duration-200", "ease-out")
    this.setCollapsed(localStorage.getItem(COLLAPSED_KEY) === "true")
    requestAnimationFrame(() => {
      this.panelTarget.classList.add("transition-[width]", "duration-200", "ease-out")
    })
    document.addEventListener("turbo:before-morph-attribute", this.preservePanelState)
    document.addEventListener("turbo:morph", this.restore)
  }

  disconnect() {
    document.removeEventListener("turbo:before-morph-attribute", this.preservePanelState)
    document.removeEventListener("turbo:morph", this.restore)
  }

  preservePanelState = (event) => {
    if (event.target === this.panelTarget && event.detail.attributeName === "class") event.preventDefault()
  }

  restore = () => this.setCollapsed(localStorage.getItem(COLLAPSED_KEY) === "true")

  collapse() {
    this.setCollapsed(!this.collapsed, true)
  }

  setCollapsed(collapsed, persist = false) {
    this.collapsed = collapsed
    if (persist) localStorage.setItem(COLLAPSED_KEY, collapsed)

    this.panelTarget.classList.toggle("w-64", !collapsed)
    this.panelTarget.classList.toggle("w-16", collapsed)
    this.expandedTargets.forEach((element) => { element.hidden = collapsed })
    this.collapsedTargets.forEach((element) => { element.hidden = !collapsed })
    this.navLinkTargets.forEach((element) => {
      element.classList.toggle("justify-center", collapsed)
      element.classList.toggle("px-2", collapsed)
      element.classList.toggle("px-3", !collapsed)
    })
    this.identityButtonTarget.classList.toggle("justify-center", collapsed)
    this.identityButtonTarget.classList.toggle("px-0", collapsed)
    this.identityButtonTarget.classList.toggle("px-2", !collapsed)
  }
}
