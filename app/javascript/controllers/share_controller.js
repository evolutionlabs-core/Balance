import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { url: String, title: String, issueUrl: String }

  async share() {
    let via = "share"

    if (navigator.share) {
      try {
        await navigator.share({ title: this.titleValue, url: this.urlValue })
      } catch (error) {
        if (error.name === "AbortError") return
        via = await this.copy()
      }
    } else {
      via = await this.copy()
    }

    if (this.hasIssueUrlValue && this.issueUrlValue) {
      if (via === "copy" && !window.confirm(`Link copied. It opens for your customer once the invoice is marked as sent.\n\nHave you sent it? Mark it as sent now?`)) return
      await this.issue(via)
    } else if (via === "copy") {
      this.element.querySelector("[data-share-label]")?.replaceChildren("Link copied")
    }
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.urlValue)
      return "copy"
    } catch {
      window.prompt("Copy this link", this.urlValue)
      return "copy"
    }
  }

  async issue(via) {
    const body = new FormData()
    body.append("delivery[send_email]", "0")
    body.append("delivery[via]", via)

    await fetch(this.issueUrlValue, {
      method: "POST",
      body,
      redirect: "manual",
      headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content || "" }
    })

    Turbo.visit(window.location.pathname, { action: "replace" })
  }
}
