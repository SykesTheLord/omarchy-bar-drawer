.pragma library

// Pure helpers for Drawer.qml. Nothing here touches QML types beyond reading
// plain properties, so the logic stays easy to reason about in isolation.

// Upper bound on items visited while looking for the host bar. A bar window
// with every widget loaded is a few thousand items at most.
var MAX_SCAN_NODES = 8000

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !isArrayLike(value)
}

// QML hands JSON-sourced lists (shell.json's `items`, `plugins`) across as
// sequence types, not native JS arrays, so Array.isArray() on them is false
// even though they index and .length like one. A literal [] fallback is a
// real JS array, so this only bites values that actually came from config —
// exactly the case that matters here.
function isArrayLike(value) {
  return Array.isArray(value)
    || (value !== null && typeof value === "object" && typeof value.length === "number")
}

function itemId(item) {
  if (typeof item === "string") return item.trim()
  if (isPlainObject(item) && item.id !== undefined && item.id !== null) return String(item.id).trim()
  return ""
}

// The `items` setting accepts bare ids or layout-style entries with inline
// settings: ["yeleticc.vpn", { "id": "omarchy.clock", "format": "HH:mm" }].
// Drawers are skipped so one drawer can never be opened from inside another.
function normalizeItems(raw, drawerId) {
  var list = isArrayLike(raw) ? raw : []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var id = itemId(list[i])
    if (!id || id === drawerId) continue
    var inline = {}
    if (isPlainObject(list[i])) {
      for (var key in list[i]) if (key !== "id") inline[key] = list[i][key]
    }
    out.push({ id: id, inline: inline })
  }
  return out
}

function pluginStub(shellConfig, id) {
  if (!isPlainObject(shellConfig) || !isArrayLike(shellConfig.plugins)) return null
  for (var i = 0; i < shellConfig.plugins.length; i++) {
    var entry = shellConfig.plugins[i]
    if (isPlainObject(entry) && String(entry.id) === id) return entry
  }
  return null
}

// Inline item keys first, then the widget's plugins[] entry. A widget that
// persists its own state calls updateEntryInline(id), which lands in plugins[]
// when the id is not in the bar layout, so that copy has to win or the
// widget would never see what it saved.
function childSettings(entry, id, shellConfig) {
  var out = {}
  if (entry && isPlainObject(entry.inline)) {
    for (var key in entry.inline) out[key] = entry.inline[key]
  }
  var stub = pluginStub(shellConfig, id)
  if (stub) {
    for (var stubKey in stub) if (stubKey !== "id") out[stubKey] = stub[stubKey]
  }
  return out
}

// The built-in Bar root. Only it has both the widget registry and the
// per-plugin facade factory.
function isHostBar(candidate) {
  return !!candidate
    && typeof candidate.pluginBarApiFor === "function"
    && typeof candidate.requestPopout === "function"
    && !!candidate.barWidgetRegistry
}

// Third-party widgets are handed a scoped facade rather than the Bar root,
// but built-in widgets on the same bar window are handed the root itself.
// Walk the window's item tree until one of them turns up.
function findHostBar(rootItem) {
  if (!rootItem) return null
  var stack = [rootItem]
  var visited = 0
  while (stack.length > 0 && visited < MAX_SCAN_NODES) {
    var node = stack.pop()
    visited++
    if (!node) continue
    var candidate = null
    try { candidate = node.bar } catch (e) { candidate = null }
    if (isHostBar(candidate)) return candidate
    var kids = node.children
    if (!kids) continue
    for (var i = 0; i < kids.length; i++) stack.push(kids[i])
  }
  return null
}

function isDescendant(item, ancestor) {
  var node = item
  var guard = 0
  while (node && guard++ < 256) {
    if (node === ancestor) return true
    node = node.parent
  }
  return false
}

// Nerd Font chevrons that point away from the bar edge.
function defaultIcon(position) {
  if (position === "bottom") return String.fromCodePoint(0xF0143)
  if (position === "left") return String.fromCodePoint(0xF0142)
  if (position === "right") return String.fromCodePoint(0xF0141)
  return String.fromCodePoint(0xF0140)
}

function clamp(value, low, high) {
  return Math.max(low, Math.min(high, value))
}
