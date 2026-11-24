import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { tokenUrl: String, connectionUrl: String, scriptUrl: String }

  async open() {
    const [ response ] = await Promise.all([ this.post(this.tokenUrlValue), this.loadScript() ])
    const { link_token } = await response.json()

    window.BeerusConnect.open(link_token, {
      onSuccess: async (publicToken) => {
        await this.post(this.connectionUrlValue, { public_token: publicToken })
        Turbo.visit(window.location.pathname)
      },
      onExit: () => {}
    })
  }

  post(url, body = {}) {
    return fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify(body)
    })
  }

  loadScript() {
    if (window.BeerusConnect) {
      return Promise.resolve()
    } else {
      return new Promise((resolve, reject) => {
        const script = document.createElement("script")
        script.src = this.scriptUrlValue
        script.onload = resolve
        script.onerror = reject
        document.head.append(script)
      })
    }
  }
}
