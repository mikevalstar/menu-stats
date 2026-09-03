.pragma library

// /proc/meminfo, every value converted from kB to bytes. Missing keys are 0.
function parseMeminfo(text) {
  var lines = String(text || "").split("\n")
  var values = {}
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^(\w+):\s+(\d+)/)
    if (match) values[match[1]] = parseInt(match[2], 10) * 1024
  }
  function get(key) { return values[key] || 0 }
  var total = get("MemTotal")
  var available = get("MemAvailable")
  return {
    total: total,
    available: available,
    used: Math.max(0, total - available),
    free: get("MemFree"),
    cached: get("Cached") + get("SReclaimable"),
    buffers: get("Buffers"),
    shmem: get("Shmem"),
    swapTotal: get("SwapTotal"),
    swapUsed: Math.max(0, get("SwapTotal") - get("SwapFree"))
  }
}
