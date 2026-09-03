import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import "../lib/Gpu.js" as Gpu
import "../lib/Format.js" as Format
import "../lib/History.js" as History

// One entry per /sys/class/drm/cardN. AMD cards are read from sysfs. NVIDIA
// exposes nothing usable there, so those go through one nvidia-smi query
// per tick, the only subprocess in the plugin. Intel is listed but reports
// unavailable.
Scope {
  id: root

  property bool enabled: false
  property int historyLength: 60
  property bool available: false
  property var sourceOptions: []
  property var data: ({})

  property var cardNames: []
  property var cardObjects: ({})
  property var histories: ({})
  property bool nvidiaSmiMissing: false

  function sample() {
    var wantNvidia = false
    for (var card in cardObjects) {
      var obj = cardObjects[card]
      if (obj.driver === "amdgpu") obj.sample()
      else if (obj.driver === "nvidia") wantNvidia = true
    }
    if (wantNvidia && !nvidiaSmiMissing && !nvidiaSmi.running) nvidiaSmi.running = true
  }

  function refreshCardNames() {
    var names = []
    for (var i = 0; i < drmFolder.count; i++) {
      var name = drmFolder.get(i, "fileName")
      if (/^card\d+$/.test(name)) names.push(name)
    }
    names.sort()
    cardNames = names
  }

  function registerCard(card, object) {
    var next = {}
    for (var key in cardObjects) next[key] = cardObjects[key]
    next[card] = object
    cardObjects = next
    publishTimer.restart()
  }

  function unregisterCard(card) {
    var next = {}
    for (var key in cardObjects) if (key !== card) next[key] = cardObjects[key]
    cardObjects = next
    publishTimer.restart()
  }

  function applyNvidia(text: string): void {
    var lines = String(text || "").split("\n")
    var nvidiaCards = []
    for (var card in cardObjects) if (cardObjects[card].driver === "nvidia") nvidiaCards.push(card)
    nvidiaCards.sort()
    var index = 0
    for (var i = 0; i < lines.length && index < nvidiaCards.length; i++) {
      var parsed = Gpu.parseNvidiaSmiLine(lines[i])
      if (!parsed) continue
      var obj = cardObjects[nvidiaCards[index]]
      obj.name = parsed.name
      obj.busy = parsed.busy
      obj.memoryUsed = parsed.memoryUsed
      obj.memoryTotal = parsed.memoryTotal
      obj.temperatureMilli = parsed.temperatureMilli
      obj.powerMicro = parsed.powerMicro
      obj.ready = true
      index++
    }
    publishTimer.restart()
  }

  function defaultCard() {
    var best = ""
    var bestRank = -1
    var names = Object.keys(cardObjects).sort()
    for (var i = 0; i < names.length; i++) {
      var rank = Gpu.driverRank(cardObjects[names[i]].driver)
      if (rank > bestRank) {
        bestRank = rank
        best = names[i]
      }
    }
    return best
  }

  function publish() {
    var names = Object.keys(cardObjects).sort()
    var options = []
    var nextHistories = {}
    var out = {}
    var anyReady = false
    for (var i = 0; i < names.length; i++) {
      var card = names[i]
      var obj = cardObjects[card]
      var label = obj.name || (Gpu.driverLabel(obj.driver) + " " + card)
      options.push({ value: card, label: label })
      var supported = obj.driver === "amdgpu" || obj.driver === "nvidia"
      var series = supported && obj.ready
        ? History.push(histories[card] || [], obj.busy, historyLength)
        : (histories[card] || [])
      nextHistories[card] = series
      if (obj.ready) anyReady = true
      var details = supported ? [
        { label: "Usage", value: Format.percent(obj.busy) },
        { label: "Memory", value: obj.memoryTotal > 0 ? Format.bytes(obj.memoryUsed) + " / " + Format.bytes(obj.memoryTotal) : "n/a" },
        { label: "Temperature", value: obj.temperatureMilli > 0 ? Format.temperature(obj.temperatureMilli) + "C" : "n/a" },
        { label: "Power", value: obj.powerMicro > 0 ? Format.watts(obj.powerMicro) : "n/a" },
        { label: "Driver", value: obj.driver }
      ] : [
        { label: "Driver", value: obj.driver },
        { label: "Frequency", value: obj.frequencyMhz > 0 ? obj.frequencyMhz + " MHz" : "n/a" },
        { label: "Usage", value: "not readable from sysfs" }
      ]
      out[card] = {
        level: obj.busy,
        levels: [obj.busy],
        text: supported ? Format.percent(obj.busy) : "n/a",
        barText: supported ? Format.percentFixed(obj.busy) : " n/a",
        series: [series],
        seriesLabels: ["Usage"],
        bars: [],
        meta: label,
        details: details
      }
    }
    var primary = defaultCard()
    if (primary !== "") {
      out[""] = out[primary]
      options.unshift({ value: "", label: "Default: " + (cardObjects[primary].name || Gpu.driverLabel(cardObjects[primary].driver) + " " + primary) })
    }
    histories = nextHistories
    sourceOptions = options
    data = out
    available = anyReady
  }

  Timer {
    id: publishTimer
    interval: 60
    onTriggered: root.publish()
  }

  FolderListModel {
    id: drmFolder
    folder: "file:///sys/class/drm"
    showDirs: true
    showFiles: false
    showDotAndDotDot: false
    showOnlyReadable: false
    onCountChanged: root.refreshCardNames()
  }

  Instantiator {
    model: root.cardNames
    delegate: Scope {
      id: cardScope

      readonly property string card: modelData
      readonly property string devicePath: "/sys/class/drm/" + card + "/device"
      property string driver: ""
      property string name: ""
      property string hwmonDir: ""
      property bool ready: false
      property real busy: 0
      property real memoryUsed: 0
      property real memoryTotal: 0
      property real temperatureMilli: 0
      property real powerMicro: 0
      property int frequencyMhz: 0

      function sample() {
        if (driver === "i915" || driver === "xe") {
          intelFrequencyFile.reload()
          return
        }
        busyFile.reload()
        vramUsedFile.reload()
        vramTotalFile.reload()
        if (hwmonDir !== "") {
          temperatureFile.reload()
          powerFile.reload()
        }
      }

      onDriverChanged: root.registerCard(card, cardScope)
      Component.onDestruction: root.unregisterCard(card)

      FileView {
        path: cardScope.devicePath + "/uevent"
        printErrors: false
        onLoaded: cardScope.driver = Gpu.parseDriver(text())
      }

      FileView {
        path: cardScope.devicePath + "/product_name"
        printErrors: false
        onLoaded: {
          var value = text().trim()
          if (value !== "") cardScope.name = value
        }
      }

      FileView {
        id: intelFrequencyFile
        path: "/sys/class/drm/" + cardScope.card + "/gt_cur_freq_mhz"
        printErrors: false
        onLoaded: cardScope.frequencyMhz = Gpu.parseMhz(text())
      }

      FileView {
        id: busyFile
        path: cardScope.devicePath + "/gpu_busy_percent"
        printErrors: false
        onLoaded: {
          cardScope.busy = Gpu.parseInteger(text()) / 100
          cardScope.ready = true
          publishTimer.restart()
        }
      }

      FileView {
        id: vramUsedFile
        path: cardScope.devicePath + "/mem_info_vram_used"
        printErrors: false
        onLoaded: cardScope.memoryUsed = Gpu.parseInteger(text())
      }

      FileView {
        id: vramTotalFile
        path: cardScope.devicePath + "/mem_info_vram_total"
        printErrors: false
        onLoaded: cardScope.memoryTotal = Gpu.parseInteger(text())
      }

      FolderListModel {
        folder: "file://" + cardScope.devicePath + "/hwmon"
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        showOnlyReadable: false
        onCountChanged: cardScope.hwmonDir = count > 0 ? get(0, "fileName") : ""
      }

      FileView {
        id: temperatureFile
        path: cardScope.hwmonDir !== "" ? cardScope.devicePath + "/hwmon/" + cardScope.hwmonDir + "/temp1_input" : ""
        printErrors: false
        onLoaded: cardScope.temperatureMilli = Gpu.parseInteger(text())
      }

      FileView {
        id: powerFile
        path: cardScope.hwmonDir !== "" ? cardScope.devicePath + "/hwmon/" + cardScope.hwmonDir + "/power1_input" : ""
        printErrors: false
        onLoaded: cardScope.powerMicro = Gpu.parseInteger(text())
      }
    }
  }

  Process {
    id: nvidiaSmi
    command: ["nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw", "--format=csv,noheader,nounits"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyNvidia(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.nvidiaSmiMissing = true
    }
  }
}
