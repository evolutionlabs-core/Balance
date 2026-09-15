import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["native", "button", "label", "menu"]
  static values = {
    compact: Boolean,
    includeBlank: Boolean,
    searchable: Boolean,
    searchInTrigger: Boolean,
    searchPlaceholder: String,
    emptyMessage: String,
    footerLabel: String,
    footerUrl: String
  }

  connect() {
    this.menu = this.menuTarget
    this.refresh()
    this.outsideHandler = (event) => {
      if (!this.element.contains(event.target) && !this.menu.contains(event.target)) this.close()
    }
    this.escapeHandler = (event) => {
      if (event.key === "Escape") this.close()
    }
    this.repositionHandler = () => {
      if (!this.menu.classList.contains("hidden")) this.positionMenu()
    }
    this.openHandler = (event) => {
      if (event.detail.controller !== this) this.close()
    }
    document.addEventListener("click", this.outsideHandler)
    document.addEventListener("keydown", this.escapeHandler)
    document.addEventListener("select-menu:open", this.openHandler)
    document.addEventListener("scroll", this.repositionHandler, true)
    window.addEventListener("resize", this.repositionHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideHandler)
    document.removeEventListener("keydown", this.escapeHandler)
    document.removeEventListener("select-menu:open", this.openHandler)
    document.removeEventListener("scroll", this.repositionHandler, true)
    window.removeEventListener("resize", this.repositionHandler)
    this.menu.remove()
  }

  toggle(event) {
    event.stopPropagation()
    this.menu.classList.contains("hidden") ? this.open() : this.close()
  }

  openFromInput(event) {
    event.stopPropagation()
    if (this.menu.classList.contains("hidden")) this.open()
  }

  open() {
    document.dispatchEvent(new CustomEvent("select-menu:open", { detail: { controller: this } }))
    const portal = this.element.closest("dialog[open]") || document.body
    portal.append(this.menu)
    this.menu.classList.remove("hidden")
    this.positionMenu()
    this.buttonTarget.setAttribute("aria-expanded", "true")
    if (this.searchInput) requestAnimationFrame(() => this.searchInput.focus())
  }

  close() {
    this.menu.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.element.append(this.menu)
    this.menu.removeAttribute("style")
    if (this.searchInTriggerValue) this.refreshLabel()
  }

  select(event) {
    this.nativeTarget.value = event.currentTarget.dataset.value
    this.nativeTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.refresh()
    this.close()
    this.buttonTarget.focus()
  }

  refresh() {
    this.menu.replaceChildren()
    this.searchInput = null
    this.emptyState = null
    if (this.searchableValue && !this.searchInTriggerValue) this.addSearch()
    if (this.hasFooterUrlValue && this.footerUrlValue) this.addFooter()

    this.optionsContainer = document.createElement("div")
    this.optionsContainer.setAttribute("role", "listbox")
    this.optionsContainer.className = this.searchableValue
      ? "max-h-40 overflow-y-auto pb-2"
      : "max-h-56 overflow-y-auto"
    this.menu.append(this.optionsContainer)

    for (const child of this.nativeTarget.children) {
      if (child.tagName === "OPTGROUP") {
        this.addGroup(child)
      } else if (child.value || this.includeBlankValue) {
        this.addOption(child)
      }
    }

    this.refreshLabel()
  }

  addGroup(group) {
    const section = document.createElement("div")
    section.dataset.selectMenuGroup = ""

    for (const option of group.children) this.addOption(option, section)
    this.optionsContainer.append(section)
  }

  addOption(option, container = this.optionsContainer) {
    const item = document.createElement("button")
    item.type = "button"
    item.dataset.value = option.value
    item.dataset.selectMenuOption = ""
    item.setAttribute("role", "option")
    item.setAttribute("aria-selected", option.selected ? "true" : "false")
    item.disabled = option.disabled
    item.className = "flex w-full cursor-pointer items-center rounded px-2 py-1.5 text-left text-sm text-neutral-700 hover:bg-neutral-100 aria-selected:bg-neutral-100 aria-selected:font-medium aria-selected:text-neutral-950"
    item.textContent = option.textContent
    item.addEventListener("click", this.select.bind(this))
    container.append(item)
  }

  addSearch() {
    const wrapper = document.createElement("div")
    wrapper.className = "border-b border-neutral-100 bg-white p-1 pb-2"

    this.searchInput = document.createElement("input")
    this.searchInput.type = "search"
    this.searchInput.placeholder = this.searchPlaceholderValue
    this.searchInput.autocomplete = "off"
    this.searchInput.className = "block w-full rounded px-2 py-1.5 text-sm text-neutral-900 outline-none placeholder:text-neutral-400 focus:bg-neutral-50"
    this.searchInput.addEventListener("input", this.search.bind(this))
    wrapper.append(this.searchInput)
    this.menu.append(wrapper)
  }

  addFooter() {
    const wrapper = document.createElement("div")
    wrapper.className = "border-b border-neutral-100 p-1 pb-2"

    const link = document.createElement("a")
    link.href = this.footerUrlValue
    link.dataset.turboFrame = "modal"
    link.className = "flex w-full items-center rounded px-2 py-1.5 text-sm font-medium text-[#0f7082] hover:bg-neutral-50"
    link.textContent = `+ ${this.footerLabelValue}`
    link.addEventListener("click", this.close.bind(this))
    wrapper.append(link)
    this.menu.append(wrapper)
  }

  positionMenu() {
    const rect = this.buttonTarget.getBoundingClientRect()
    const gap = 4
    const width = this.compactValue ? Math.max(rect.width, 256) : rect.width
    const left = Math.min(rect.left, window.innerWidth - width - gap)

    this.menu.style.left = `${Math.max(gap, left)}px`
    this.menu.style.width = `${width}px`
    this.menu.style.top = `${rect.bottom + gap}px`
    this.menu.style.zIndex = "60"

    const menuHeight = this.menu.getBoundingClientRect().height
    const roomBelow = window.innerHeight - rect.bottom - gap
    const roomAbove = rect.top - gap

    if (menuHeight > roomBelow && roomAbove > roomBelow) {
      this.menu.style.top = `${Math.max(gap, rect.top - menuHeight - gap)}px`
    }
    this.menu.style.maxHeight = `${Math.max(96, window.innerHeight - (gap * 2))}px`
    this.menu.style.overflowY = "auto"
  }

  search(event) {
    const query = event.currentTarget.value.trim().toLowerCase()
    if (this.searchInTriggerValue) {
      this.labelTarget.classList.toggle("text-neutral-400", !query)
      this.labelTarget.classList.toggle("text-neutral-950", Boolean(query))
      const selectedOption = this.nativeTarget.selectedOptions[0]
      if (selectedOption?.value && selectedOption.textContent.trim().toLowerCase() !== query) {
        this.nativeTarget.value = ""
        this.nativeTarget.dispatchEvent(new Event("change", { bubbles: true }))
      }
      if (this.menu.classList.contains("hidden")) this.open()
    }
    const options = [...this.optionsContainer.querySelectorAll("[data-select-menu-option]")]

    for (const option of options) {
      option.classList.toggle("hidden", !option.textContent.toLowerCase().includes(query))
    }

    for (const group of this.optionsContainer.querySelectorAll("[data-select-menu-group]")) {
      group.classList.toggle("hidden", !group.querySelector("[data-select-menu-option]:not(.hidden)"))
    }

    this.showEmptyState(options.every((option) => option.classList.contains("hidden")))
  }

  showEmptyState(show) {
    if (!this.emptyState) {
      this.emptyState = document.createElement("p")
      this.emptyState.className = "hidden px-2 py-4 text-center text-sm text-neutral-400"
      this.emptyState.textContent = this.emptyMessageValue
      this.optionsContainer.append(this.emptyState)
    }
    this.emptyState.classList.toggle("hidden", !show)
  }

  refreshLabel() {
    const option = this.nativeTarget.selectedOptions[0]
    const selected = option?.value
    if (this.searchInTriggerValue) {
      this.labelTarget.value = selected ? option.textContent : ""
    } else {
      this.labelTarget.textContent = selected ? option.textContent : this.nativeTarget.options[0]?.textContent
    }
    this.labelTarget.classList.toggle("text-neutral-400", !selected)
    this.labelTarget.classList.toggle("text-neutral-950", Boolean(selected))
  }
}
