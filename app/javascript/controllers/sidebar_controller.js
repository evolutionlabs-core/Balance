import { Controller } from "@hotwired/stimulus"
import { acquireOverlay, releaseOverlay } from "lib/overlay"

const COLLAPSED_KEY = "balance:sidebar-collapsed"
const DESKTOP_QUERY = "(min-width: 1024px)"
const FOCUSABLE = 'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])'

export default class extends Controller {
  static targets = ["panel", "hamburger", "panelButton"]

  connect() {
    this.open = false
    this.desktopQuery = window.matchMedia(DESKTOP_QUERY)
    this.applyRail(this.readRail())
    if (this.isDesktop()) this.panelTarget.show()
    this.readyFrame = requestAnimationFrame(() => this.element.setAttribute("data-sidebar-ready", ""))
    this.desktopQuery.addEventListener("change", this.handleBreakpoint)
    this.element.addEventListener("keydown", this.handleKeydown)
    document.addEventListener("overlay:opened", this.handleOverlayOpened)
    document.addEventListener("turbo:morph", this.handleMorph)
    document.addEventListener("turbo:before-cache", this.handleBeforeCache)
  }

  disconnect() {
    this.desktopQuery?.removeEventListener("change", this.handleBreakpoint)
    this.element.removeEventListener("keydown", this.handleKeydown)
    document.removeEventListener("overlay:opened", this.handleOverlayOpened)
    document.removeEventListener("turbo:morph", this.handleMorph)
    document.removeEventListener("turbo:before-cache", this.handleBeforeCache)
    cancelAnimationFrame(this.readyFrame)
    if (this.panelTarget.open) this.panelTarget.close()
    releaseOverlay(this)
    this.open = false
  }

  toggleDrawer() {
    if (this.open) {
      this.closeDrawer({ restoreFocus: true })
    } else {
      this.openDrawer()
    }
  }

  openDrawer() {
    if (this.open || this.isDesktop()) return
    this.open = true
    this.trigger = document.activeElement
    this.panelTarget.showModal()
    this.render()
    acquireOverlay(this)
    this.panelButtonTarget.focus({ preventScroll: true })
  }

  closeDrawer(options = {}) {
    if (!this.open) return
    const restoreFocus = options instanceof Event ? true : options.restoreFocus !== false
    this.open = false
    this.panelTarget.close()
    this.render()
    releaseOverlay(this)
    if (restoreFocus && this.trigger && document.contains(this.trigger)) {
      this.trigger.focus()
    }
    this.trigger = null
  }

  closeOnNavigate() {
    const event = arguments[0]
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    const link = event.target.closest("a[href]")
    if (!link) return
    if (link.href === window.location.href) event.preventDefault()
    this.closeDrawer({ restoreFocus: false })
  }

  clickOutside(event) {
    if (event.target === this.panelTarget) this.closeDrawer({ restoreFocus: true })
  }

  togglePanel() {
    if (this.isDesktop()) {
      this.toggleRail()
    } else {
      this.closeDrawer({ restoreFocus: true })
    }
  }

  toggleRail() {
    if (!this.isDesktop()) return
    this.applyRail(!this.collapsed, true)
  }

  handleKeydown = (event) => {
    if (event.key === "Tab" && this.open) this.containFocus(event)
    if (event.key === "Escape") {
      if (this.open) {
        this.closeDrawer({ restoreFocus: true })
      }
    }
  }

  handleBreakpoint = (event) => {
    if (event.matches) {
      this.closeDrawer({ restoreFocus: false })
      if (!this.panelTarget.open) this.panelTarget.show()
      this.hamburgerTarget.setAttribute("aria-expanded", "false")
      this.syncPanelButton()
    } else {
      if (this.panelTarget.contains(document.activeElement)) this.hamburgerTarget.focus()
      if (this.panelTarget.open) this.panelTarget.close()
      this.render()
    }
  }

  handleMorph = () => {
    this.applyRail(this.readRail())
    this.closeDrawer({ restoreFocus: false })
  }

  handleBeforeCache = () => {
    this.closeDrawer({ restoreFocus: false })
  }

  handleOverlayOpened = (event) => {
    if (event.detail.owner !== this) this.closeDrawer({ restoreFocus: false })
  }

  render() {
    this.element.setAttribute("data-drawer", this.open ? "open" : "closed")
    this.hamburgerTarget.setAttribute("aria-expanded", String(this.open))
    this.hamburgerTarget.setAttribute("aria-label", this.open ? "Close navigation" : "Open navigation")
    this.syncPanelButton()
  }

  applyRail(collapsed, persist = false) {
    this.collapsed = collapsed
    if (persist) this.writeRail(collapsed)
    this.element.setAttribute("data-rail", collapsed ? "collapsed" : "expanded")
    this.syncPanelButton()
  }

  readRail() {
    try {
      return localStorage.getItem(COLLAPSED_KEY) === "true"
    } catch {
      return false
    }
  }

  writeRail(collapsed) {
    try {
      localStorage.setItem(COLLAPSED_KEY, String(collapsed))
    } catch {}
  }

  isDesktop() {
    return this.desktopQuery?.matches ?? window.matchMedia(DESKTOP_QUERY).matches
  }

  syncPanelButton() {
    if (this.isDesktop()) {
      this.panelButtonTarget.setAttribute("aria-expanded", String(!this.collapsed))
      this.panelButtonTarget.setAttribute("aria-label", this.collapsed ? "Expand sidebar" : "Collapse sidebar")
    } else {
      this.panelButtonTarget.setAttribute("aria-expanded", String(this.open))
      this.panelButtonTarget.setAttribute("aria-label", "Close navigation")
    }
  }

  containFocus(event) {
    const controls = [...this.panelTarget.querySelectorAll(FOCUSABLE)].filter((control) => control.offsetParent)
    const first = controls[0]
    const last = controls.at(-1)
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

}
