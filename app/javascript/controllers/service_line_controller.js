import { Controller } from "@hotwired/stimulus"
import { formatAmount } from "lib/money"

export default class extends Controller {
  static targets = [ "service", "description", "quantity", "rate", "amount", "menu", "link", "linkName" ]
  static values = { catalog: String }

  search() {
    const query = this.descriptionTarget.value.trim().toLowerCase()
    if (!query && this.serviceTarget.value) this.unlink()

    this.matches = this.services.filter(service =>
      !query || service.name.toLowerCase().includes(query) || service.description.toLowerCase().includes(query)
    ).slice(0, 8)
    this.activeIndex = -1
    this.render()
  }

  navigate(event) {
    if (this.menuTarget.hidden) {
      if (event.key === "ArrowDown") this.search()
      return
    }

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      this.activeIndex = (this.activeIndex + step + this.matches.length) % this.matches.length
      this.render()
    } else if (event.key === "Enter" && this.activeIndex >= 0) {
      event.preventDefault()
      this.choose(this.matches[this.activeIndex])
    } else if (event.key === "Escape") {
      this.close()
    }
  }

  pick(event) {
    event.preventDefault()
    this.choose(this.matches[Number(event.currentTarget.dataset.index)])
  }

  choose(service) {
    this.serviceTarget.value = service.id
    this.descriptionTarget.value = service.description || service.name
    if (!this.quantityTarget.value) this.quantityTarget.value = "1"
    if (service.rate) this.rateTarget.value = Number.parseFloat(service.rate).toFixed(2)
    this.showLink(service.name)
    this.close()
    this.calculateAmount()
    this.rateTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  unlink() {
    this.serviceTarget.value = ""
    this.linkTarget.hidden = true
    this.descriptionTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  close() {
    this.menuTarget.hidden = true
    this.descriptionTarget.setAttribute("aria-expanded", "false")
  }

  calculateAmount() {
    const quantity = Number.parseFloat(this.quantityTarget.value || this.quantityTarget.placeholder) || 0
    const rate = Number.parseFloat(this.rateTarget.value) || 0

    this.amountTarget.value = (quantity * rate).toFixed(2)
    this.amountTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  formatMoney(event) {
    const input = event.target
    if (input.value === "") return

    const value = Number.parseFloat(input.value)
    if (Number.isFinite(value)) input.value = value.toFixed(2)
  }

  showLink(name) {
    this.linkNameTarget.textContent = name
    this.linkTarget.hidden = false
  }

  render() {
    this.menuTarget.replaceChildren(...this.matches.map((service, index) => this.option(service, index)))
    const open = this.matches.length > 0
    this.menuTarget.hidden = !open
    this.descriptionTarget.setAttribute("aria-expanded", String(open))
  }

  option(service, index) {
    const option = document.createElement("li")
    option.setAttribute("role", "option")
    option.setAttribute("aria-selected", String(index === this.activeIndex))
    option.dataset.index = index
    option.dataset.action = "mousedown->service-line#pick"
    option.className = "flex cursor-pointer items-center justify-between gap-3 rounded px-2.5 py-2 text-sm text-neutral-900 hover:bg-neutral-100 aria-selected:bg-neutral-100"

    const name = document.createElement("span")
    name.className = "truncate"
    name.textContent = service.name
    option.append(name)

    if (service.rate) {
      const rate = document.createElement("span")
      rate.className = "shrink-0 tabular-nums text-neutral-500"
      rate.textContent = formatAmount(Number.parseFloat(service.rate))
      option.append(rate)
    }
    return option
  }

  get services() {
    const catalog = document.getElementById(this.catalogValue)
    this.catalog ||= catalog ? JSON.parse(catalog.textContent) : []
    return this.catalog
  }
}
