import { renderJson } from "json_view"

// The page Reclame Aqui returned is shown in a sandboxed iframe (no scripts,
// same origin so it can be inspected). Hovering a JSON key outlines the
// element it came from: list items are found by the link they carry, other
// keys through the engine's XRAY selector map.

const HIT_CSS = `
  .xray-hit {
    outline: 3px solid #f59e0b !important;
    outline-offset: 3px !important;
    background-color: rgba(245, 158, 11, 0.12) !important;
    border-radius: 6px;
  }
`

const root = document.getElementById("playground")
const config = JSON.parse(root.dataset.config)
const form = document.getElementById("pg-form")
const tabs = document.getElementById("engine-tabs")
const fields = document.getElementById("fields")
const examples = document.getElementById("examples")
const runButton = document.getElementById("run")
const bar = document.getElementById("bar")
const jsonPane = document.getElementById("json")
const frame = document.getElementById("frame")
const frameEmpty = document.getElementById("frame-empty")
const rawLink = document.getElementById("raw-link")

let engine = config.engines[0]
let results = null

function selectEngine(name, values = {}) {
  engine = config.engines.find((candidate) => candidate.name === name) || engine
  tabs.replaceChildren(...config.engines.map(engineTab))
  renderFields(values)
  examples.replaceChildren(...engine.examples.map(exampleChip))
}

function engineTab(candidate) {
  const button = node("button", { type: "button", "aria-pressed": String(candidate === engine) }, candidate.name)
  button.addEventListener("click", () => selectEngine(candidate.name))
  return button
}

function exampleChip(example) {
  const button = node("button", { type: "button" }, Object.values(example).join(" · "))
  button.addEventListener("click", () => {
    renderFields(example)
    run()
  })
  return button
}

function renderFields(values) {
  fields.replaceChildren(...engine.params.map((param) => {
    const id = `field-${param.name}`
    const label = node("label", { for: id }, param.name)
    if (param.required) label.append(node("span", { class: "req", title: "required" }, "*"))

    let input
    if (param.allowed) {
      input = node("select", { id, name: param.name })
      param.allowed.forEach((option) => input.append(node("option", { value: option }, option)))
      input.value = values[param.name] ?? param.default ?? param.allowed[0]
    } else {
      input = node("input", { id, name: param.name, placeholder: param.default ?? "", autocomplete: "off", spellcheck: "false" })
      input.value = values[param.name] ?? ""
      input.required = param.required
    }

    return node("div", { class: "field" }, label, input, describe(param.description))
  }))
}

// Descriptions use `backticks` for code, rendered without innerHTML.
function describe(text) {
  const hint = node("div", { class: "hint" })
  text.split("`").forEach((part, index) => hint.append(index % 2 ? node("code", {}, part) : part))
  return hint
}

function currentParams() {
  const params = new URLSearchParams({ engine: engine.name })
  for (const [name, raw] of new FormData(form)) {
    const value = String(raw).trim()
    const spec = engine.params.find((param) => param.name === name)
    if (value === "" || (spec && spec.default === value)) continue
    params.set(name, value)
  }
  return params
}

async function run() {
  if (!form.reportValidity()) return

  const params = currentParams()
  history.replaceState(null, "", `/playground?${params}`)
  runButton.disabled = true
  bar.replaceChildren(node("span", { class: "badge processing" }, "Searching"), node("code", { class: "request" }, `GET /search.json?${params}`))

  try {
    const response = await fetch(`/search.json?${params}`, { headers: { Accept: "application/json" } })
    results = await response.json()
    renderBar(params, results, response.status)
    renderJson(jsonPane, results, { onHover: xray, onLink: followApiLink })
    await showPage(results.search_metadata)
  } catch (error) {
    bar.replaceChildren(node("span", { class: "badge error" }, "Failed"), node("span", {}, error.message))
  } finally {
    runButton.disabled = false
  }
}

function renderBar(params, data, httpStatus) {
  const metadata = data.search_metadata || {}
  const status = metadata.status || "Error"
  const items = [node("span", { class: `badge ${status.toLowerCase()}` }, status)]
  if (metadata.total_time_taken != null) items.push(node("span", {}, `${metadata.total_time_taken} s`))
  if (data.error) items.push(node("span", { class: "muted" }, data.error))
  if (httpStatus >= 400 && !metadata.status) items.push(node("span", { class: "muted" }, `HTTP ${httpStatus}`))
  items.push(node("code", { class: "request" }, `GET /search.json?${params}`))
  if (metadata.json_endpoint) items.push(node("a", { href: metadata.json_endpoint, target: "_blank" }, "json_endpoint"))
  bar.replaceChildren(...items)
}

async function showPage(metadata) {
  const available = metadata && metadata.raw_html_file
  frame.hidden = !available
  frameEmpty.hidden = Boolean(available)
  rawLink.hidden = !available
  if (!available) return

  rawLink.href = metadata.raw_html_file
  const response = await fetch(`/searches/${metadata.id}/preview`)
  frame.srcdoc = await response.text()
}

frame.addEventListener("load", () => {
  const doc = frame.contentDocument
  if (!doc || !doc.head) return
  const style = doc.createElement("style")
  style.textContent = HIT_CSS
  doc.head.append(style)
})

function xray(path) {
  const doc = frame.contentDocument
  if (!doc || !doc.body || frame.hidden) return

  doc.querySelectorAll(".xray-hit").forEach((hit) => hit.classList.remove("xray-hit"))
  jsonPane.querySelectorAll(".jv-row.hit").forEach((row) => row.classList.remove("hit"))

  const target = findSource(doc, path)
  if (!target) return
  target.classList.add("xray-hit")

  // scrollIntoView would also scroll the playground itself, so only the
  // iframe's window moves.
  const view = doc.defaultView
  const box = target.getBoundingClientRect()
  view.scrollTo({ top: box.top + view.scrollY - Math.max((view.innerHeight - box.height) / 2, 24), behavior: "smooth" })
}

function findSource(doc, path) {
  // The nearest list item on the path, matched by the Reclame Aqui link it holds.
  let value = results
  const items = []
  path.forEach((key) => {
    value = value?.[key]
    if (typeof key === "number" && value && typeof value.link === "string") items.push(value)
  })
  for (const item of items.reverse()) {
    const match = elementLinkingTo(doc, item.link)
    if (match) return match
  }

  // Otherwise the most specific selector the engine maps this path to.
  const keys = path.filter((key) => typeof key === "string")
  for (let length = keys.length; length > 0; length--) {
    const selector = engine.xray[keys.slice(0, length).join(".")]
    const match = selector && doc.querySelector(selector)
    if (match) return match
  }
  return null
}

function elementLinkingTo(doc, link) {
  let url
  try { url = new URL(link) } catch { return null }
  if (!url.hostname.endsWith("reclameaqui.com.br")) return null

  const id = url.pathname.match(/_([\w-]+)\/?$/)?.[1]
  const anchor = [...doc.querySelectorAll("a[href]")].find((candidate) => {
    const href = candidate.getAttribute("href")
    return href.endsWith(url.pathname) || (id && href.includes(`_${id}`))
  })
  return anchor && (anchor.closest("li, article, [data-testid*='card'], [data-testid*='item']") || anchor)
}

// api_link values run in the playground instead of opening raw JSON.
function followApiLink(href) {
  const url = new URL(href)
  if (url.origin !== location.origin || url.pathname !== "/search.json") return false
  selectEngine(url.searchParams.get("engine"), Object.fromEntries(url.searchParams))
  run()
  return true
}

function node(tag, attributes = {}, ...children) {
  const element = document.createElement(tag)
  Object.entries(attributes).forEach(([name, value]) => element.setAttribute(name, value))
  element.append(...children)
  return element
}

form.addEventListener("submit", (event) => {
  event.preventDefault()
  run()
})

const initial = new URLSearchParams(location.search)
selectEngine(initial.get("engine") || "reclame_aqui_company", Object.fromEntries(initial))
if (initial.get("engine")) run()
