import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = [ "error" ]
  static values = { tokenUrl: String, connectionUrl: String, scriptUrl: String }

  async open() {
    this.element.disabled = true

    try {
      const [ response ] = await Promise.all([ this.post(this.tokenUrlValue), this.loadScript() ])
      const { link_token } = await response.json()

      window.BeerusConnect.open(link_token, {
        onSuccess: (publicToken) => this.exchange(publicToken),
        onExit: (error) => this.exit(error)
      })
    } catch {
      this.fail()
    }
  }

  async exchange(publicToken) {
    try {
      await this.post(this.connectionUrlValue, { public_token: publicToken })
      Turbo.visit(window.location.pathname)
    } catch {
      this.fail()
    }
  }

  exit(error) {
    if (error) {
      this.fail()
    } else {
      this.element.disabled = false
    }
  }

  fail() {
    document.getElementById("flash_messages").append(this.errorTarget.content.cloneNode(true))
    this.element.disabled = false
  }

  async post(url, body = {}) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify(body)
    })

    if (response.ok) {
      return response
    } else {
      throw new Error(`Bank linking failed with ${response.status}`)
    }
  }

  loadScript() {
    if (window.BeerusConnect) {
      return Promise.resolve()
    } else {
      return new Promise((resolve, reject) => {
        const script = document.createElement("script")
        script.src = this.scriptUrlValue
        script.onload = resolve
        script.onerror = () => {
          script.remove()
          reject(new Error("Beerus Connect did not load"))
        }
        document.head.append(script)
      })
    }
  }
}
