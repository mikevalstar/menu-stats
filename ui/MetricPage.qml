import QtQuick
import qs.Commons
import qs.Ui
import "../lib/Metrics.js" as Metrics
import "../lib/Format.js" as Format

// Detail page for one strip item: hero, framed history graph with a legend
// and scale, per-core meters, filesystem usage bars, top processes, and the
// detail rows. Sections the sampler does not provide simply do not appear.
Column {
  id: root

  property var item: ({ metric: "cpu", style: "graph" })
  property var sampler: null
  property var processes: null
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  readonly property var metric: Metrics.metric(item.metric)
  readonly property string source: item.source || ""
  readonly property var view: sampler && sampler.data ? (sampler.data[source] || sampler.data[""] || null) : null
  readonly property int capacity: sampler ? sampler.historyLength : 60
  readonly property bool isRate: metric ? metric.kind === "rate" : false
  readonly property var bars: view && view.bars ? view.bars : []
  readonly property var usage: view && view.usage ? view.usage : []
  readonly property var seriesLabels: view && view.seriesLabels ? view.seriesLabels : []
  readonly property var processRows: processes && processes.enabled ? processes.rows : []
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

  width: parent ? parent.width : implicitWidth
  spacing: Style.spacing.lg

  PanelHero {
    title: root.metric ? root.metric.name : ""
    meta: root.view ? root.view.meta : ""
    detail: root.view ? root.view.text : (root.sampler && root.sampler.available === false ? "n/a" : "…")
    foreground: root.foreground
    fontFamily: root.fontFamily
    iconComponent: Component {
      Text {
        textFormat: Text.PlainText
        text: root.metric ? root.metric.glyph : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.display
      }
    }
  }

  PanelSeparator { foreground: root.foreground }

  // ------------------------------------------------------------ graph

  Sparkline {
    id: graph
    width: parent.width
    height: Style.space(84)
    series: root.view ? root.view.series : []
    capacity: root.capacity
    maxValue: root.view && root.view.maxValue !== undefined ? root.view.maxValue : (root.isRate ? 0 : 1)
    minScale: root.isRate ? 1024 : 1
    color: root.foreground
    lineWidth: 1.5
    framed: true
  }

  Item {
    width: parent.width
    implicitHeight: legend.implicitHeight

    Row {
      id: legend
      anchors.left: parent.left
      spacing: Style.spacing.lg

      Repeater {
        model: root.seriesLabels.length > 1 ? root.seriesLabels : []
        Row {
          required property string modelData
          required property int index
          spacing: Style.spacing.sm

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(8)
            height: Style.space(8)
            color: index === 0 ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35) : "transparent"
            border.width: 1
            border.color: index === 0 ? root.foreground : Qt.darker(root.foreground, 1.7)
          }

          Text {
            textFormat: Text.PlainText
            text: modelData
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Text {
        visible: root.seriesLabels.length <= 1
        textFormat: Text.PlainText
        text: root.seriesLabels.length === 1 ? root.seriesLabels[0] : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Text {
      anchors.right: parent.right
      textFormat: Text.PlainText
      text: root.isRate ? "scale " + Format.rate(graph.effectiveMax)
        : (root.view && root.view.maxValue > 1 ? "scale " + Format.temperature(root.view.maxValue) + "C" : "last " + root.capacity + " samples")
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // ------------------------------------------------------------ cores

  Row {
    id: barRow
    visible: root.bars.length > 0
    width: parent.width
    spacing: Style.space(2)
    readonly property real meterWidth: root.bars.length > 0
      ? (width - spacing * (root.bars.length - 1)) / root.bars.length : 0

    Repeater {
      model: root.bars
      Meter {
        required property real modelData
        width: barRow.meterWidth
        height: Style.space(28)
        level: modelData
        color: root.foreground
      }
    }
  }

  // ------------------------------------------------------------ filesystems

  Column {
    visible: root.usage.length > 0
    width: parent.width
    spacing: Style.spacing.md

    PanelSectionHeader {
      text: "Filesystems"
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Repeater {
      model: root.usage
      Column {
        required property var modelData
        width: parent.width
        spacing: Style.spacing.xs

        Item {
          width: parent.width
          implicitHeight: mountLabel.implicitHeight

          Text {
            id: mountLabel
            anchors.left: parent.left
            anchors.right: mountValue.left
            anchors.rightMargin: Style.spacing.md
            textFormat: Text.PlainText
            text: modelData.label
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          Text {
            id: mountValue
            anchors.right: parent.right
            textFormat: Text.PlainText
            text: modelData.text
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(4)
          color: root.faint

          Rectangle {
            width: parent.width * Math.max(0, Math.min(1, modelData.fraction))
            height: parent.height
            color: modelData.fraction > 0.9 ? Color.urgent : root.foreground
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ processes

  Column {
    visible: root.processes !== null && root.processes.enabled
    width: parent.width
    spacing: Style.spacing.xs

    Item {
      width: parent.width
      implicitHeight: processHeader.implicitHeight + Style.spacing.xs

      PanelSectionHeader {
        id: processHeader
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: "Top processes"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Text {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(64)
        anchors.bottom: parent.bottom
        textFormat: Text.PlainText
        text: "CPU"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        textFormat: Text.PlainText
        text: "MEM"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Text {
      visible: root.processRows.length === 0
      textFormat: Text.PlainText
      text: "Measuring…"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Repeater {
      model: root.processRows
      Item {
        required property var modelData
        width: parent.width
        implicitHeight: processName.implicitHeight + Style.spacing.xxs

        Text {
          id: processName
          anchors.left: parent.left
          anchors.right: processCpu.left
          anchors.rightMargin: Style.spacing.md
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: modelData.name
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          id: processCpu
          anchors.right: parent.right
          anchors.rightMargin: Style.space(64)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: (modelData.cpu * 100).toFixed(1) + "%"
          color: modelData.cpu >= 0.005 ? root.foreground : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: Format.bytes(modelData.memory)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }

  // ------------------------------------------------------------ details

  PanelSeparator {
    visible: root.view && root.view.details.length > 0
    foreground: root.foreground
  }

  Repeater {
    model: root.view ? root.view.details : []
    DetailRow {
      required property var modelData
      header: modelData.header !== undefined
      label: modelData.header !== undefined ? modelData.header : modelData.label
      value: modelData.value || ""
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }
}
