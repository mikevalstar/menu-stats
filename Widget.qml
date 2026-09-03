import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Cpu.js" as Cpu

// Bar icon plus a detail flyout for CPU. The root is the shell's Panel base
// so the bar can summon, hide, and toggle it over IPC and coordinate it with
// the other popups. Sampling runs from here on a fixed timer whether or not
// the flyout is open, because the bar readout will need history later.
Panel {
  id: root
  moduleName: "valstar.menu-stats"
  ipcTarget: moduleName

  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string cpuGlyph: "󰻠"
  readonly property int sampleIntervalMs: 1000

  // Sampler state. `previous` is the last /proc/stat snapshot from
  // Cpu.parseStat; usage is the delta against it, so nothing is reported
  // until the second sample lands.
  property var previous: null
  property real usage: 0
  property var coreUsage: []
  property string cpuModel: ""
  property string loadAverage: ""

  readonly property int usagePercent: Math.round(usage * 100)
  readonly property int coreCount: coreUsage.length

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function applyStat(text: string): void {
    var snapshot = Cpu.parseStat(text)
    if (!snapshot) return
    if (previous) {
      var result = Cpu.usageBetween(previous, snapshot)
      usage = result.total
      coreUsage = result.cores
    }
    previous = snapshot
  }

  // ------------------------------------------------------------ sampling

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
    path: "/proc/cpuinfo"
    printErrors: false
    onLoaded: root.cpuModel = Cpu.parseModelName(text())
  }

  Timer {
    interval: root.sampleIntervalMs
    running: true
    repeat: true
    onTriggered: {
      statFile.reload()
      if (root.opened) loadFile.reload()
    }
  }

  onOpenedChanged: if (opened) loadFile.reload()

  // ------------------------------------------------------------ bar icon

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.cpuGlyph
    active: root.opened
    tooltipText: "CPU " + root.usagePercent + "%"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
    }
  }

  // ------------------------------------------------------------ flyout

  component StatRow: Item {
    property string label: ""
    property string value: ""

    width: parent ? parent.width : implicitWidth
    implicitHeight: labelText.implicitHeight

    Text {
      id: labelText
      anchors.left: parent.left
      textFormat: Text.PlainText
      text: parent.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      anchors.right: parent.right
      textFormat: Text.PlainText
      text: parent.value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(300))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.spacing.lg

        PanelHero {
          title: "CPU"
          meta: root.cpuModel
          detail: root.usagePercent + "%"
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: root.cpuGlyph
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          text: "Cores"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        // One thin meter per core, filled from the bottom.
        Row {
          id: coreRow
          width: parent.width
          spacing: Style.space(2)
          readonly property real meterWidth: root.coreCount > 0
            ? (width - spacing * (root.coreCount - 1)) / root.coreCount : 0

          Repeater {
            model: root.coreUsage
            delegate: Item {
              required property real modelData
              width: coreRow.meterWidth
              height: Style.space(28)

              Rectangle {
                anchors.fill: parent
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
              }

              Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(1, parent.height * modelData)
                color: root.foreground
              }
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        StatRow { label: "Load average"; value: root.loadAverage }
        StatRow { label: "Cores"; value: String(root.coreCount) }
      }
    }
  }
}
