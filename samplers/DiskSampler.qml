import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Disk.js" as Disk
import "../lib/Format.js" as Format
import "../lib/History.js" as History

// Bytes per second read and written per whole disk from /proc/diskstats.
Scope {
  id: root

  property bool enabled: false
  property int historyLength: 60
  property bool available: false
  property var sourceOptions: [{ value: "", label: "All disks" }]
  property var data: ({})

  property var previous: null
  property real previousTime: 0
  property var histories: ({})
  property var mounts: []
  property real lastSpaceCheck: 0
  readonly property int spaceIntervalMs: 30000

  onEnabledChanged: {
    if (!enabled) previous = null
    else if (Date.now() - lastSpaceCheck > spaceIntervalMs) refreshSpace()
  }

  function sample() {
    diskstatsFile.reload()
    if (Date.now() - lastSpaceCheck > spaceIntervalMs) refreshSpace()
  }

  // Free space needs statfs, which no /proc file provides, so this is one
  // df call every 30 seconds while a disk item is in the strip.
  function refreshSpace() {
    lastSpaceCheck = Date.now()
    if (!dfProcess.running) dfProcess.running = true
  }

  function usageRows() {
    var rows = []
    for (var i = 0; i < mounts.length; i++) {
      var m = mounts[i]
      rows.push({
        label: m.target,
        fraction: m.size > 0 ? m.used / m.size : 0,
        text: Format.bytes(m.used) + " / " + Format.bytes(m.size)
      })
    }
    return rows
  }

  function apply(text: string): void {
    var snapshot = Disk.parseDiskstats(text)
    var now = Date.now()
    sourceOptions = Disk.sourceOptions(snapshot)
    if (previous) {
      var rates = Disk.ratesBetween(previous, snapshot, (now - previousTime) / 1000)
      var nextHistories = {}
      var out = {}
      for (var name in rates) {
        var kept = histories[name] || { read: [], write: [] }
        var read = History.push(kept.read, rates[name].read, historyLength)
        var write = History.push(kept.write, rates[name].write, historyLength)
        nextHistories[name] = { read: read, write: write }
        var peak = Math.max(History.max(read), History.max(write), 1024)
        out[name] = {
          level: Math.max(rates[name].read, rates[name].write) / peak,
          levels: [rates[name].read / peak, rates[name].write / peak],
          text: Format.rate(rates[name].read) + " R  " + Format.rate(rates[name].write) + " W",
          barText: "R" + Format.rateShort(rates[name].read) + " W" + Format.rateShort(rates[name].write),
          series: [read, write],
          seriesLabels: ["Read", "Write"],
          bars: [],
          meta: name === "" ? "All disks" : name,
          usage: usageRows(),
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
      { label: "Read", value: Format.rate(rates[name].read) },
      { label: "Write", value: Format.rate(rates[name].write) }
    ]
    if (name !== "") {
      rows.push({ label: "Total read", value: Format.bytes(snapshot[name].read) })
      rows.push({ label: "Total written", value: Format.bytes(snapshot[name].write) })
      return rows
    }
    var names = []
    for (var disk in rates) if (disk !== "") names.push(disk)
    names.sort()
    for (var i = 0; i < names.length; i++) {
      rows.push({ label: names[i], value: "R" + Format.rateShort(rates[names[i]].read) + " W" + Format.rateShort(rates[names[i]].write) })
    }
    return rows
  }

  Process {
    id: dfProcess
    command: ["df", "-B1", "--output=source,target,fstype,size,used"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.mounts = Disk.parseDf(text)
    }
  }

  FileView {
    id: diskstatsFile
    path: "/proc/diskstats"
    printErrors: false
    onLoaded: root.apply(text())
  }
}
