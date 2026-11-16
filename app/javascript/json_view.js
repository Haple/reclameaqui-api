// A small collapsible JSON viewer. Every row remembers its path in the
// document (["related_companies", 2, "score"]) so the playground can map a
// hovered key back to the element it was parsed from.

const COLLAPSE_ARRAYS_LONGER_THAN = 6

export function renderJson(container, value, { onHover, onLink } = {}) {
  const root = element("div", "json")
  appendNode(root, null, value, [], 0, true)
  container.replaceChildren(root)

  root.addEventListener("mouseover", (event) => {
    const row = event.target.closest(".jv-row")
    if (row && onHover) onHover(row.path)
  })

  root.addEventListener("click", (event) => {
    const link = event.target.closest("a")
    if (link && onLink && onLink(link.href)) event.preventDefault()
  })
}

function appendNode(parent, key, value, path, depth, last) {
  const row = element("div", "jv-row")
  row.style.setProperty("--depth", depth)
  row.path = path
  if (key !== null) row.append(keyLabel(key), ": ")

  if (value === null || typeof value !== "object") {
    row.append(scalar(value), last ? "" : ",")
    parent.append(row)
    return
  }

  const isArray = Array.isArray(value)
  const entries = isArray ? value.map((item, index) => [index, item]) : Object.entries(value)
  const [open, close] = isArray ? ["[", "]"] : ["{", "}"]
  const comma = last ? "" : ","

  if (entries.length === 0) {
    row.append(`${open}${close}${comma}`)
    parent.append(row)
    return
  }

  const toggle = element("button", "jv-toggle", "▾")
  toggle.type = "button"
  toggle.setAttribute("aria-label", "Collapse")
  const summary = element("span", "jv-meta", ` ${entries.length} ${isArray ? "items" : "keys"} ${close}${comma}`)
  summary.hidden = true
  row.prepend(toggle)
  row.append(open, summary)

  const children = element("div")
  entries.forEach(([childKey, child], index) => {
    appendNode(children, isArray ? null : childKey, child, [...path, childKey], depth + 1, index === entries.length - 1)
  })

  const closing = element("div", "jv-row", `${close}${comma}`)
  closing.style.setProperty("--depth", depth)
  closing.path = path

  parent.append(row, children, closing)

  const setCollapsed = (collapsed) => {
    children.hidden = collapsed
    closing.hidden = collapsed
    summary.hidden = !collapsed
    toggle.textContent = collapsed ? "▸" : "▾"
    toggle.setAttribute("aria-label", collapsed ? "Expand" : "Collapse")
  }
  toggle.addEventListener("click", () => setCollapsed(!children.hidden))
  if (isArray && depth >= 2 && entries.length > COLLAPSE_ARRAYS_LONGER_THAN) setCollapsed(true)
}

function keyLabel(key) {
  return element("span", "jv-key", JSON.stringify(String(key)))
}

function scalar(value) {
  if (value === null) return element("span", "jv-null", "null")
  if (typeof value === "string") {
    const span = element("span", "jv-string")
    if (/^https?:\/\//.test(value)) {
      const link = element("a", null, JSON.stringify(value))
      link.href = value
      link.target = "_blank"
      link.rel = "noopener"
      span.append(link)
    } else {
      span.textContent = JSON.stringify(value)
    }
    return span
  }
  return element("span", `jv-${typeof value}`, String(value))
}

function element(tag, className, text) {
  const node = document.createElement(tag)
  if (className) node.className = className
  if (text !== undefined) node.textContent = text
  return node
}
