import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Cpu.js" as Cpu
import "../lib/Format.js" as Format
import "../lib/History.js" as History

// Aggregate and per-core busy fraction from /proc/stat deltas, plus the
// bits of context the page shows: model, frequency, load average.
Scope {
  id: root

  property bool enabled: false
  property int historyLength: 60
  property bool available: false
  readonly property var sourceOptions: []
  property var data: ({})

  property var previous: null
  property var history: []
  property var cores: []
  property real usage: 0
  property string model: ""
  property string loadAverage: ""
  property int frequencyKhz: 0

  onEnabledChanged: if (!enabled) previous = null

  function sample() {
    statFile.reload()
    loadFile.reload()
    frequencyFile.reload()
  }

  function applyStat(text: string): void {
    var snapshot = Cpu.parseStat(text)
    if (!snapshot) return
    if (previous) {
      var result = Cpu.usageBetween(previous, snapshot)
      usage = result.total
      cores = result.cores
      history = History.push(history, usage, historyLength)
      available = true
      publish()
    }
    previous = snapshot
  }

  function publish() {
    data = { "": {
      level: usage,
      levels: [usage],
      text: Format.percent(usage),
      barText: Format.percentFixed(usage),
      series: [history],
      seriesLabels: ["Usage"],
      bars: cores,
      meta: model,
      details: [
        { label: "Usage", value: Format.percent(usage) },
        { label: "Cores", value: String(cores.length) },
        { label: "Frequency", value: frequencyKhz > 0 ? Format.frequency(frequencyKhz) : "n/a" },
        { label: "Load average", value: loadAverage }
      ]
    } }
  }

  FileView {
    id: statFile
    path: "/proc/stat"
    printErrors: false
    onLoaded: root.applyStat(text())
  }

  FileView {
    id: loadFile
    path: "/proc/loadavg"
    printErrors: false
    onLoaded: root.loadAverage = Cpu.parseLoadAverage(text())
  }

  FileView {
    id: frequencyFile
    path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
    printErrors: false
    onLoaded: root.frequencyKhz = Cpu.parseFrequencyKhz(text())
  }

  FileView {
    path: "/proc/cpuinfo"
    printErrors: false
    onLoaded: root.model = Cpu.parseModelName(text())
  }
}
