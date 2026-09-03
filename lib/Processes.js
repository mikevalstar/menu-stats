.pragma library

// One `cat /proc/[0-9]*/stat` per tick gives every process's name, CPU
// ticks, and resident pages in a single read. CPU share is the tick delta
// between two reads over wall time, USER_HZ being 100 on Linux.

var USER_HZ = 100
var PAGE_BYTES = 4096

// pid -> { name, ticks, rssPages }
function parseStats(text) {
  var lines = String(text || "").split("\n")
  var out = {}
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^(\d+) \((.*)\) \S (.*)$/)
    if (!match) continue
    var rest = match[3].split(" ")
    // Fields after the state: index 10 is utime, 11 stime, 20 rss (pages).
    if (rest.length < 21) continue
    out[match[1]] = {
      name: match[2],
      ticks: (parseInt(rest[10], 10) || 0) + (parseInt(rest[11], 10) || 0),
      rssPages: parseInt(rest[20], 10) || 0
    }
  }
  return out
}

// Rows sorted by CPU share or memory. `cpu` is the fraction of the whole
// machine (all cores), `memory` is resident bytes.
function topBetween(previous, next, seconds, cores, sortBy, limit) {
  var rows = []
  var coreCount = Math.max(1, cores)
  for (var pid in next) {
    var entry = next[pid]
    var before = previous ? previous[pid] : null
    var cpu = 0
    if (before && seconds > 0) {
      cpu = Math.max(0, (entry.ticks - before.ticks) / (seconds * USER_HZ)) / coreCount
    }
    rows.push({ pid: parseInt(pid, 10), name: entry.name, cpu: cpu, memory: entry.rssPages * PAGE_BYTES })
  }
  rows.sort(function(a, b) {
    if (sortBy === "memory") return b.memory - a.memory || b.cpu - a.cpu
    return b.cpu - a.cpu || b.memory - a.memory
  })
  return rows.slice(0, limit)
}
