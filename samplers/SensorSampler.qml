import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import "../lib/Sensors.js" as Sensors
import "../lib/Format.js" as Format
import "../lib/History.js" as History

// Every temperature and fan channel under /sys/class/hwmon. Chips and
// channels are enumerated once with FolderListModel; each channel's
// _input file is re-read on sample. Readings land in a plain object and a
// short timer coalesces the burst of loads into one publish.
Scope {
  id: root

  property bool enabled: false
  property int historyLength: 60
  property bool available: false
  property var sourceOptions: []
  property var data: ({})

  property var hwmonDirs: []
  property var chipIds: ({})
  property var readings: ({})
  property var histories: ({})

  function sample() {
    for (var i = 0; i < chips.count; i++) {
      var chip = chips.objectAt(i)
      if (!chip) continue
      for (var j = 0; j < chip.channels.count; j++) {
        var channel = chip.channels.objectAt(j)
        if (channel) channel.sample()
      }
    }
  }

  function refreshHwmonDirs() {
    var dirs = []
    for (var i = 0; i < hwmonFolder.count; i++) {
      var name = hwmonFolder.get(i, "fileName")
      if (/^hwmon\d+$/.test(name)) dirs.push(name)
    }
    dirs.sort(function(a, b) { return parseInt(a.substr(5), 10) - parseInt(b.substr(5), 10) })
    hwmonDirs = dirs
  }

  // Chip ids are the driver name, with "#2", "#3" for repeats in hwmon
  // order, so two NVMe drives do not share every sensor id.
  function recomputeChipIds() {
    var seen = {}
    var ids = {}
    for (var i = 0; i < chips.count; i++) {
      var chip = chips.objectAt(i)
      if (!chip || chip.chipName === "") continue
      var count = (seen[chip.chipName] || 0) + 1
      seen[chip.chipName] = count
      ids[chip.dir] = count === 1 ? chip.chipName : chip.chipName + "#" + count
    }
    chipIds = ids
  }

  function report(id, type, label, value) {
    if (id === "") return
    readings[id] = { type: type, label: label, value: value }
    publishTimer.restart()
  }

  function publish() {
    var ids = Object.keys(readings)
    ids.sort(function(a, b) {
      var ra = readings[a], rb = readings[b]
      if (ra.type !== rb.type) return ra.type === "temp" ? -1 : 1
      var pa = Sensors.preferredRank(a.split("/")[0]), pb = Sensors.preferredRank(b.split("/")[0])
      if (pa !== pb) return pa - pb
      return a < b ? -1 : (a > b ? 1 : 0)
    })
    var options = []
    var nextHistories = {}
    var out = {}
    var allRows = []
    for (var i = 0; i < ids.length; i++) {
      var id = ids[i]
      var reading = readings[id]
      var series = History.push(histories[id] || [], reading.value, historyLength)
      nextHistories[id] = series
      var text = reading.type === "temp" ? Format.temperature(reading.value) + "C" : Format.rpm(reading.value)
      var barText = reading.type === "temp" ? Format.temperature(reading.value).padStart(4, " ") : String(Math.round(reading.value)).padStart(4, " ")
      var level = Sensors.level(reading.type, reading.value)
      options.push({ value: id, label: reading.label })
      allRows.push({ label: reading.label, value: text })
      out[id] = {
        level: level,
        levels: [level],
        text: text,
        barText: barText,
        series: [series],
        seriesLabels: [reading.type === "temp" ? "Temperature" : "Speed"],
        bars: [],
        meta: reading.label,
        details: [],
        maxValue: reading.type === "temp" ? 100000 : 0
      }
    }
    for (var k = 0; k < ids.length; k++) out[ids[k]].details = allRows
    if (ids.length > 0) out[""] = out[ids[0]]
    histories = nextHistories
    sourceOptions = options
    data = out
    available = ids.length > 0
  }

  Timer {
    id: publishTimer
    interval: 80
    onTriggered: root.publish()
  }

  FolderListModel {
    id: hwmonFolder
    folder: "file:///sys/class/hwmon"
    showDirs: true
    showFiles: false
    showDotAndDotDot: false
    showOnlyReadable: false
    onCountChanged: root.refreshHwmonDirs()
  }

  Instantiator {
    id: chips
    model: root.hwmonDirs
    delegate: Scope {
      id: chipScope

      readonly property string dir: modelData
      readonly property string path: "/sys/class/hwmon/" + dir
      property string chipName: ""
      readonly property string chipId: root.chipIds[dir] || ""
      property var channelFiles: []
      readonly property alias channels: channelInstantiator

      onChipNameChanged: root.recomputeChipIds()

      FileView {
        path: chipScope.path + "/name"
        printErrors: false
        onLoaded: chipScope.chipName = text().trim()
      }

      FolderListModel {
        folder: "file://" + chipScope.path
        nameFilters: ["temp*_input", "fan*_input"]
        showDirs: false
        showOnlyReadable: false
        onCountChanged: {
          var files = []
          for (var i = 0; i < count; i++) files.push(get(i, "fileName"))
          files.sort()
          chipScope.channelFiles = files
        }
      }

      Instantiator {
        id: channelInstantiator
        model: chipScope.channelFiles
        delegate: Scope {
          id: channelScope

          readonly property string file: modelData
          readonly property string type: Sensors.channelType(file)
          property string label: ""
          property real value: 0
          readonly property string id: chipScope.chipId !== "" ? Sensors.sensorId(chipScope.chipId, label, file) : ""
          readonly property string displayLabel: chipScope.chipId !== "" ? Sensors.displayLabel(chipScope.chipId, label, file) : ""

          function sample() {
            inputFile.reload()
          }

          FileView {
            path: chipScope.path + "/" + channelScope.file.replace(/_input$/, "_label")
            printErrors: false
            onLoaded: channelScope.label = text().trim()
          }

          FileView {
            id: inputFile
            path: chipScope.path + "/" + channelScope.file
            printErrors: false
            onLoaded: {
              var n = parseInt(text().trim(), 10)
              if (!isFinite(n)) return
              channelScope.value = n
              root.report(channelScope.id, channelScope.type, channelScope.displayLabel, n)
            }
          }

          // Ids resolve after the chip name loads, which can be after the
          // first input read. Re-report once the id is known.
          onIdChanged: if (id !== "" && value !== 0) root.report(id, type, displayLabel, value)
        }
      }
    }
  }
}
