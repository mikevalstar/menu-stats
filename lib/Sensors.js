.pragma library

// hwmon channel files look like temp1_input, fan2_input.
function channelType(fileName) {
  if (/^temp\d+_input$/.test(fileName)) return "temp"
  if (/^fan\d+_input$/.test(fileName)) return "fan"
  return ""
}

function channelName(fileName) {
  return fileName.replace(/_input$/, "")
}

// Stable id for a channel: chip name plus label, or channel name when the
// driver gives no label. Callers add "#n" for repeated chips.
function sensorId(chip, label, fileName) {
  var tail = label && label.length > 0 ? label : channelName(fileName)
  return chip + "/" + tail
}

function displayLabel(chip, label, fileName) {
  var tail = label && label.length > 0 ? label : channelName(fileName)
  return tail + " (" + chip + ")"
}

// Chips whose first temperature is the sensible default CPU reading.
var PREFERRED_CHIPS = ["k10temp", "zenpower", "coretemp", "cpu_thermal", "acpitz"]

function preferredRank(chip) {
  var base = chip.replace(/#\d+$/, "")
  var index = PREFERRED_CHIPS.indexOf(base)
  return index === -1 ? PREFERRED_CHIPS.length : index
}

// 0..1 level for the meter style. Temperatures span 0 to 100°C, fans 0 to
// 6000 rpm; both are display conventions, not limits.
function level(type, value) {
  if (type === "temp") return Math.max(0, Math.min(1, value / 100000))
  if (type === "fan") return Math.max(0, Math.min(1, value / 6000))
  return 0
}
