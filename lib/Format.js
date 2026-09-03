.pragma library

// Display formatting for values the samplers produce. Inputs are always in
// base units: fractions 0..1, bytes, bytes per second, millidegrees, kHz.

function percent(fraction) {
  return Math.round(Math.max(0, Math.min(1, fraction)) * 100) + "%"
}

// Fixed-width percent so the text style does not jitter: " 4%", "42%", "100%".
function percentFixed(fraction) {
  return percent(fraction).padStart(4, " ")
}

var UNITS = ["B", "K", "M", "G", "T"]

function scaled(bytes) {
  var value = Math.max(0, Number(bytes) || 0)
  var unit = 0
  while (value >= 1024 && unit < UNITS.length - 1) {
    value /= 1024
    unit++
  }
  return { value: value, unit: UNITS[unit] }
}

function bytes(n) {
  var s = scaled(n)
  var digits = s.unit === "B" ? 0 : (s.value < 10 ? 1 : 0)
  return s.value.toFixed(digits) + " " + (s.unit === "B" ? "B" : s.unit + "B")
}

function rate(bytesPerSecond) {
  var s = scaled(bytesPerSecond)
  var digits = s.unit === "B" ? 0 : (s.value < 10 ? 1 : 0)
  return s.value.toFixed(digits) + " " + (s.unit === "B" ? "B/s" : s.unit + "B/s")
}

// Short rate for the bar: "1.2M", " 45K", "  0B". Always 4 characters.
function rateShort(bytesPerSecond) {
  var s = scaled(bytesPerSecond)
  var digits = s.unit === "B" ? 0 : (s.value < 10 ? 1 : 0)
  return (s.value.toFixed(digits) + s.unit).padStart(4, " ")
}

function dualRate(down, up) {
  return "↓" + rateShort(down) + " ↑" + rateShort(up)
}

function temperature(milliDegrees) {
  return Math.round((Number(milliDegrees) || 0) / 1000) + "°"
}

function rpm(value) {
  return Math.round(Number(value) || 0) + " rpm"
}

function frequency(kHz) {
  var mhz = (Number(kHz) || 0) / 1000
  return mhz >= 1000 ? (mhz / 1000).toFixed(2) + " GHz" : Math.round(mhz) + " MHz"
}

function watts(microWatts) {
  return ((Number(microWatts) || 0) / 1e6).toFixed(1) + " W"
}
