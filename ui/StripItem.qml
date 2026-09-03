import QtQuick
import qs.Commons
import qs.Ui
import "../lib/Metrics.js" as Metrics

// One item in the bar strip, drawn in the item's style. Built on
// WidgetButton so it registers as a bar click target: clicking it while
// another panel is open switches panels in one click, like the first-party
// icons.
WidgetButton {
  id: root

  property var item: ({ metric: "cpu", style: "graph" })
  property var sampler: null
  property bool showIcon: true

  readonly property var metric: Metrics.metric(item.metric)
  readonly property string source: item.source || ""
  readonly property var view: sampler && sampler.data ? (sampler.data[source] || sampler.data[""] || null) : null
  readonly property int capacity: sampler ? sampler.historyLength : 60
  readonly property bool isRate: metric ? metric.kind === "rate" : false
  readonly property color drawColor: active && useActiveColor ? activeColor : foreground
  readonly property string valueText: view ? view.text : (sampler && sampler.available === false ? "n/a" : "…")
  readonly property real graphHeight: barSize - Style.space(12)
  readonly property var usage: view && view.usage ? view.usage : []
  readonly property var barLines: view && view.barLines ? view.barLines : []

  function usageTooltip(): string {
    var parts = []
    for (var i = 0; i < usage.length; i++) parts.push(usage[i].label + " " + usage[i].text)
    return parts.join("   ")
  }

  labelVisible: false
  hasVisualContent: true
  tooltipText: (metric ? metric.name : "") + "  " + (item.style === "space" && usage.length > 0 ? usageTooltip() : valueText)
  fixedWidth: content.implicitWidth + scaledHorizontalMargin * 2

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(4)

    Text {
      visible: root.showIcon && root.metric !== null
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: root.metric ? root.metric.glyph : ""
      color: root.drawColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.iconSmall
    }

    Loader {
      anchors.verticalCenter: parent.verticalCenter
      sourceComponent: root.item.style === "meter" ? meterStyle
        : root.item.style === "text" ? (root.barLines.length === 2 ? twoLineTextStyle : textStyle)
        : root.item.style === "space" ? spaceStyle : graphStyle
    }
  }

  Component {
    id: graphStyle
    Sparkline {
      width: Style.space(48)
      height: root.graphHeight
      series: root.view ? root.view.series : []
      capacity: root.capacity
      maxValue: root.view && root.view.maxValue !== undefined ? root.view.maxValue : (root.isRate ? 0 : 1)
      minScale: root.isRate ? 1024 : 1
      mirrored: root.isRate
      color: root.drawColor
    }
  }

  // Download above upload, at caption size so both fit the bar height.
  Component {
    id: twoLineTextStyle
    Column {
      spacing: 0
      Repeater {
        model: root.barLines
        Text {
          required property string modelData
          textFormat: Text.PlainText
          text: modelData
          color: root.drawColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          lineHeight: 0.9
          renderType: Text.NativeRendering
        }
      }
    }
  }

  // One thin horizontal bar per mounted filesystem, fullest first is not
  // needed; mount order matches the page.
  Component {
    id: spaceStyle
    Column {
      spacing: Style.space(2)
      Repeater {
        model: root.usage.slice(0, 4)
        Item {
          required property var modelData
          width: Style.space(40)
          height: Style.space(3)

          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.drawColor.r, root.drawColor.g, root.drawColor.b, 0.15)
          }

          Rectangle {
            width: parent.width * Math.max(0, Math.min(1, modelData.fraction))
            height: parent.height
            color: modelData.fraction > 0.9 ? root.activeColor : root.drawColor
          }
        }
      }
    }
  }

  Component {
    id: meterStyle
    Row {
      spacing: Style.space(3)
      Repeater {
        model: root.view ? root.view.levels : [0]
        Meter {
          required property real modelData
          width: Style.space(6)
          height: root.graphHeight
          level: modelData
          color: root.drawColor
        }
      }
    }
  }

  Component {
    id: textStyle
    Text {
      textFormat: Text.PlainText
      text: root.view ? root.view.barText : "  --"
      color: root.drawColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      renderType: Text.NativeRendering
    }
  }
}
