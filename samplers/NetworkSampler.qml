import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Network.js" as Network
import "../lib/Format.js" as Format
import "../lib/History.js" as History

// Bytes per second down and up per interface from /proc/net/dev deltas,
// timed against the wall clock so a late tick does not inflate the rate.
Scope {
  id: root

  property bool enabled: false
  property int historyLength: 60
  property bool available: false
  property var sourceOptions: [{ value: "", label: "All interfaces" }]
  property var data: ({})

  property var previous: null
  property real previousTime: 0
  property var histories: ({})

  onEnabledChanged: if (!enabled) previous = null

  function sample() {
    netDevFile.reload()
  }

  function apply(text: string): void {
    var snapshot = Network.parseNetDev(text)
    var now = Date.now()
    sourceOptions = Network.sourceOptions(snapshot)
    if (previous) {
      var rates = Network.ratesBetween(previous, snapshot, (now - previousTime) / 1000)
      var nextHistories = {}
      var out = {}
      for (var name in rates) {
        var kept = histories[name] || { down: [], up: [] }
        var down = History.push(kept.down, rates[name].down, historyLength)
        var up = History.push(kept.up, rates[name].up, historyLength)
        nextHistories[name] = { down: down, up: up }
        var peak = Math.max(History.max(down), History.max(up), 1024)
        out[name] = {
          level: Math.max(rates[name].down, rates[name].up) / peak,
          levels: [rates[name].down / peak, rates[name].up / peak],
          text: Format.rate(rates[name].down) + " ↓  " + Format.rate(rates[name].up) + " ↑",
          barText: Format.dualRate(rates[name].down, rates[name].up),
          barLines: ["↓" + Format.rateShort(rates[name].down), "↑" + Format.rateShort(rates[name].up)],
          series: [down, up],
          seriesLabels: ["Download", "Upload"],
          bars: [],
          meta: name === "" ? "All physical interfaces" : name,
          details: detailsFor(name, rates, snapshot)
        }
      }
      histories = nextHistories
      data = out
      available = true
    }
    previous = snapshot
    previousTime = now
  }

  function detailsFor(name, rates, snapshot) {
    var rows = [
      { label: "Download", value: Format.rate(rates[name].down) },
      { label: "Upload", value: Format.rate(rates[name].up) }
    ]
    if (name !== "") {
      rows.push({ label: "Received", value: Format.bytes(snapshot[name].rx) })
      rows.push({ label: "Sent", value: Format.bytes(snapshot[name].tx) })
      return rows
    }
    var names = []
    for (var iface in rates) if (iface !== "" && iface !== "lo") names.push(iface)
    names.sort()
    for (var i = 0; i < names.length; i++) {
      rows.push({ label: names[i], value: Format.dualRate(rates[names[i]].down, rates[names[i]].up) })
    }
    return rows
  }

  FileView {
    id: netDevFile
    path: "/proc/net/dev"
    printErrors: false
    onLoaded: root.apply(text())
  }
}
