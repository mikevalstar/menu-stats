.pragma library

// The metric catalogue and the settings shape. Anything that needs to know
// which metrics exist, what they are called, or how an item is validated
// goes through here, so the strip, the flyout, and the config page agree.

var METRICS = {
  cpu:     { name: "CPU",     glyph: "󰻠", kind: "level", hasSources: false },
  memory:  { name: "Memory",  glyph: "󰍛", kind: "level", hasSources: false },
  gpu:     { name: "GPU",     glyph: "󰢮", kind: "level", hasSources: true },
  network: { name: "Network", glyph: "󰛳", kind: "rate",  hasSources: true },
  disk:    { name: "Disk",    glyph: "󰋊", kind: "rate",  hasSources: true },
  sensor:  { name: "Sensor",  glyph: "󰔏", kind: "value", hasSources: true }
}

var METRIC_ORDER = ["cpu", "memory", "gpu", "network", "disk", "sensor"]

var STYLES = [
  { value: "graph", label: "Graph" },
  { value: "meter", label: "Meter" },
  { value: "text",  label: "Text" }
]

var DEFAULT_ITEMS = [
  { metric: "cpu", style: "graph" },
  { metric: "memory", style: "meter" },
  { metric: "network", style: "graph" }
]

var LIMITS = {
  intervalMs: { min: 250, max: 10000, fallback: 1000 },
  historyLength: { min: 20, max: 600, fallback: 60 }
}

function metric(id) {
  return METRICS[id] || null
}

function metricOptions() {
  var out = []
  for (var i = 0; i < METRIC_ORDER.length; i++) {
    out.push({ value: METRIC_ORDER[i], label: METRICS[METRIC_ORDER[i]].name })
  }
  return out
}

function styleValid(style) {
  for (var i = 0; i < STYLES.length; i++) if (STYLES[i].value === style) return true
  return false
}

// Validate the raw `items` setting. Unknown metrics or styles are dropped,
// sources are coerced to strings, and the result is always an array.
function normalizeItems(raw) {
  if (!Array.isArray(raw)) return DEFAULT_ITEMS.slice()
  var out = []
  for (var i = 0; i < raw.length; i++) {
    var entry = raw[i]
    if (!entry || typeof entry !== "object") continue
    if (!METRICS[entry.metric]) continue
    var style = styleValid(entry.style) ? entry.style : "graph"
    var item = { metric: entry.metric, style: style }
    if (typeof entry.source === "string" && entry.source !== "") item.source = entry.source
    out.push(item)
  }
  return out
}

// The set of metrics the strip needs sampled, as { metric: true }.
function neededMetrics(items) {
  var out = {}
  for (var i = 0; i < items.length; i++) out[items[i].metric] = true
  return out
}

function clampInt(value, limit) {
  var n = parseInt(value, 10)
  if (!isFinite(n)) return limit.fallback
  return Math.max(limit.min, Math.min(limit.max, n))
}
