const owners = new Set()

export function acquireOverlay(owner) {
  owners.add(owner)
  document.body.classList.add("overflow-hidden")
  document.dispatchEvent(new CustomEvent("overlay:opened", { detail: { owner } }))
}

export function releaseOverlay(owner) {
  owners.delete(owner)
  if (owners.size === 0) document.body.classList.remove("overflow-hidden")
}
