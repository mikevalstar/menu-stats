.pragma library

// Pure parsers for the CPU sampler in Widget.qml. Everything here takes the
// raw text of a /proc file and returns plain data, so the QML side only has
// to hold state and bind it to the UI.

// Snapshot of the cpu lines in /proc/stat. Index 0 is the aggregate "cpu"
// line, 1..n are cpu0..cpuN-1. Each entry is { total, idle } in jiffies.
// Returns null when the text has no cpu lines.
function parseStat(text) {
  var lines = String(text || "").split("\n")
  var rows = []
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].trim().split(/\s+/)
    if (parts.length < 5 || parts[0].indexOf("cpu") !== 0) continue
    // user nice system idle iowait irq softirq steal. Guest time is already
    // counted inside user, so it is left out of the total.
    var total = 0
    for (var j = 1; j <= 8 && j < parts.length; j++) total += parseInt(parts[j], 10) || 0
    var idle = (parseInt(parts[4], 10) || 0) + (parseInt(parts[5], 10) || 0)
    rows.push({ total: total, idle: idle })
  }
  return rows.length > 0 ? rows : null
}

// Busy fraction 0..1 for every row between two snapshots.
// Returns { total, cores } where total is the aggregate and cores is one
// value per core in cpu0..cpuN-1 order.
function usageBetween(previous, next) {
  var count = Math.min(previous.length, next.length)
  var cores = []
  var total = 0
  for (var i = 0; i < count; i++) {
    var deltaTotal = next[i].total - previous[i].total
    var deltaIdle = next[i].idle - previous[i].idle
    var busy = deltaTotal > 0 ? (deltaTotal - deltaIdle) / deltaTotal : 0
    busy = Math.min(1, Math.max(0, busy))
    if (i === 0) total = busy
    else cores.push(busy)
  }
  return { total: total, cores: cores }
}

// The three load averages from /proc/loadavg as one display string.
function parseLoadAverage(text) {
  var parts = String(text || "").trim().split(/\s+/)
  return parts.length >= 3 ? parts.slice(0, 3).join("  ") : ""
}

// The first "model name" from /proc/cpuinfo, or "" when absent.
function parseModelName(text) {
  var match = String(text || "").match(/^model name\s*:\s*(.+)$/m)
  return match ? match[1].trim() : ""
}

// scaling_cur_freq is kHz as a bare integer.
function parseFrequencyKhz(text) {
  var n = parseInt(String(text || "").trim(), 10)
  return isFinite(n) ? n : 0
}
