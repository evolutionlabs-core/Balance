let sequence = 0

export function appendRow(container, template) {
  sequence += 1
  container.insertAdjacentHTML("beforeend", template.innerHTML.replaceAll("__INDEX__", `${Date.now()}${sequence}`))
}

export function removeRow(row) {
  const destroy = row.querySelector("input[name$='[_destroy]']")

  if (destroy && row.querySelector("input[name$='[id]']")) {
    destroy.value = "1"
    row.hidden = true
  } else {
    row.remove()
  }
}

export function visibleRows(rows) {
  return rows.filter((row) => !row.hidden)
}
