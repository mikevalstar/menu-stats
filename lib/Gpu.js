.pragma library

// DRIVER= line of /sys/class/drm/cardN/device/uevent.
function parseDriver(text) {
  var match = String(text || "").match(/^DRIVER=(.+)$/m)
  return match ? match[1].trim() : ""
}

// One line of `nvidia-smi --query-gpu=name,utilization.gpu,memory.used,
// memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits`.
// Memory comes back in MiB, temperature in °C, power in W.
function parseNvidiaSmiLine(line) {
  var parts = String(line || "").split(",")
  if (parts.length < 6) return null
  function num(index) {
    var n = parseFloat(parts[index])
    return isFinite(n) ? n : 0
  }
  return {
    name: parts[0].trim(),
    busy: num(1) / 100,
    memoryUsed: num(2) * 1024 * 1024,
    memoryTotal: num(3) * 1024 * 1024,
    temperatureMilli: num(4) * 1000,
    powerMicro: num(5) * 1e6
  }
}

function parseInteger(text) {
  var n = parseInt(String(text || "").trim(), 10)
  return isFinite(n) ? n : 0
}

// Rank for choosing the default card: the discrete GPU wins over the
// integrated one when both are present.
function driverRank(driver) {
  if (driver === "nvidia") return 3
  if (driver === "amdgpu") return 2
  if (driver === "i915" || driver === "xe") return 1
  return 0
}

function driverLabel(driver) {
  if (driver === "nvidia") return "NVIDIA"
  if (driver === "amdgpu") return "AMD"
  if (driver === "i915" || driver === "xe") return "Intel"
  return driver || "Unknown"
}

// Intel exposes no busy counter in sysfs, only the current GT frequency.
function parseMhz(text) {
  var n = parseInt(String(text || "").trim(), 10)
  return isFinite(n) ? n : 0
}
