.pragma library

// /proc/net/dev counters per interface, in bytes.
function parseNetDev(text) {
  var lines = String(text || "").split("\n")
  var out = {}
  for (var i = 2; i < lines.length; i++) {
    var match = lines[i].match(/^\s*([^:\s]+):\s*(.*)$/)
    if (!match) continue
    var fields = match[2].trim().split(/\s+/)
    if (fields.length < 9) continue
    out[match[1]] = { rx: parseInt(fields[0], 10) || 0, tx: parseInt(fields[8], 10) || 0 }
  }
  return out
}

// Interfaces whose traffic already crossed a physical one, or never leaves
// the machine. Excluded from the "all interfaces" total.
function isVirtual(name) {
  return /^(lo|tailscale|docker|veth|br-|virbr|wg|tun|tap|vmnet|podman|cni|flannel)/.test(name)
}

// Bytes per second per interface between two snapshots, plus "" for the sum
// of physical interfaces. Interfaces missing from either snapshot are skipped.
function ratesBetween(previous, next, seconds) {
  var out = { "": { down: 0, up: 0 } }
  if (!(seconds > 0)) return out
  for (var name in next) {
    if (!previous[name]) continue
    var down = Math.max(0, (next[name].rx - previous[name].rx) / seconds)
    var up = Math.max(0, (next[name].tx - previous[name].tx) / seconds)
    out[name] = { down: down, up: up }
    if (!isVirtual(name)) {
      out[""].down += down
      out[""].up += up
    }
  }
  return out
}

function sourceOptions(snapshot) {
  var names = []
  for (var name in snapshot) if (name !== "lo") names.push(name)
  names.sort()
  var out = [{ value: "", label: "All interfaces" }]
  for (var i = 0; i < names.length; i++) out.push({ value: names[i], label: names[i] })
  return out
}
