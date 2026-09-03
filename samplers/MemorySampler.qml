import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Memory.js" as Memory
import "../lib/Format.js" as Format
import "../lib/History.js" as History

// Used memory as a fraction of total, where used is what the kernel says is
// not available, so cache that can be dropped does not count.
Scope {
  id: root

  property bool enabled: false
  property int historyLength: 60
  property bool available: false
  readonly property var sourceOptions: []
  property var data: ({})

  property var history: []

  function sample() {
    meminfoFile.reload()
  }

  function apply(text: string): void {
    var info = Memory.parseMeminfo(text)
    if (info.total <= 0) return
    var fraction = info.used / info.total
    history = History.push(history, fraction, historyLength)
    available = true
    var swapText = info.swapTotal > 0
      ? Format.bytes(info.swapUsed) + " / " + Format.bytes(info.swapTotal)
      : "none"
    data = { "": {
      level: fraction,
      levels: [fraction],
      text: Format.percent(fraction),
      barText: Format.percentFixed(fraction),
      series: [history],
      seriesLabels: ["Used"],
      bars: [],
      meta: Format.bytes(info.total) + " total",
      details: [
        { label: "Used", value: Format.bytes(info.used) },
        { label: "Available", value: Format.bytes(info.available) },
        { label: "Cached", value: Format.bytes(info.cached) },
        { label: "Shared", value: Format.bytes(info.shmem) },
        { label: "Free", value: Format.bytes(info.free) },
        { label: "Swap", value: swapText }
      ]
    } }
  }

  FileView {
    id: meminfoFile
    path: "/proc/meminfo"
    printErrors: false
    onLoaded: root.apply(text())
  }
}
