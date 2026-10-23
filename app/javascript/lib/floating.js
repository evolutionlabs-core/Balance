const GAP = 4
const MARGIN = 8

export function placeBelow(floating, anchor, { align = "start" } = {}) {
  floating.style.position = "fixed"

  const origin = fixedOrigin(floating)
  const anchorBox = anchor.getBoundingClientRect()
  const { width, height } = floating.getBoundingClientRect()
  const left = align === "end" ? anchorBox.right - width : anchorBox.left
  const roomBelow = window.innerHeight - anchorBox.bottom - GAP
  const roomAbove = anchorBox.top - GAP
  const top = height > roomBelow && roomAbove > roomBelow ? anchorBox.top - height - GAP : anchorBox.bottom + GAP

  floating.style.left = `${Math.max(MARGIN, Math.min(left, window.innerWidth - width - MARGIN)) - origin.left}px`
  floating.style.top = `${Math.max(MARGIN, top) - origin.top}px`
}

function fixedOrigin(floating) {
  floating.style.left = "0px"
  floating.style.top = "0px"
  const { left, top } = floating.getBoundingClientRect()
  return { left, top }
}
