import QtQuick
import qs.Commons
import qs.Ui
import "../lib/Metrics.js" as Metrics

// Detail page for one strip item: hero, large history graph, per-part
// meters when the sampler provides them, then the detail rows.
Column {
  id: root

  property var item: ({ metric: "cpu", style: "graph" })
  property var sampler: null
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  readonly property var metric: Metrics.metric(item.metric)
  readonly property string source: item.source || ""
  readonly property var view: sampler && sampler.data ? (sampler.data[source] || sampler.data[""] || null) : null
  readonly property int capacity: sampler ? sampler.historyLength : 60
  readonly property bool isRate: metric ? metric.kind === "rate" : false
  readonly property var bars: view && view.bars ? view.bars : []
  readonly property var seriesLabels: view && view.seriesLabels ? view.seriesLabels : []
  readonly property color dim: Qt.darker(foreground, 1.4)

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

  Sparkline {
    width: parent.width
    height: Style.space(72)
    series: root.view ? root.view.series : []
    capacity: root.capacity
    maxValue: root.view && root.view.maxValue !== undefined ? root.view.maxValue : (root.isRate ? 0 : 1)
    minScale: root.isRate ? 1024 : 1
    color: root.foreground
    lineWidth: 1.5
  }

  Row {
    visible: root.seriesLabels.length > 1
    spacing: Style.spacing.lg

    Repeater {
      model: root.seriesLabels
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
  }

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

  PanelSeparator {
    visible: root.view && root.view.details.length > 0
    foreground: root.foreground
  }

  Repeater {
    model: root.view ? root.view.details : []
    DetailRow {
      required property var modelData
      label: modelData.label
      value: modelData.value
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
  }
}
