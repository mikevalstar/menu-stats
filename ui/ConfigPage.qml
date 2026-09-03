import QtQuick
import qs.Commons
import qs.Ui
import "../lib/Metrics.js" as Metrics

// The preferences page: what is in the strip, in what style, from which
// source, plus sampling. Every edit is emitted as a signal and the widget
// persists it; this page never holds state of its own beyond the add row.
Column {
  id: root

  property var items: []
  property int intervalMs: 1000
  property int historyLength: 60
  property bool showIcons: true
  property var service: null
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  signal itemsEdited(var next)
  signal intervalEdited(int value)
  signal historyEdited(int value)
  signal showIconsEdited(bool value)

  // The add section's draft. Changing the metric resets style and source,
  // since neither carries over meaningfully.
  property string addMetric: "cpu"
  property string addStyle: "graph"
  property string addSource: ""
  readonly property var addMetricInfo: Metrics.metric(addMetric)
  readonly property string addSourceLabel: {
    var options = sourceOptionsFor(addMetric)
    for (var i = 0; i < options.length; i++) if (options[i].value === addSource) return options[i].label
    return ""
  }
  readonly property string addSummary: (addMetricInfo ? addMetricInfo.name : addMetric)
    + " as " + Metrics.styleLabel(addMetric, addStyle)
    + (addMetricInfo && addMetricInfo.hasSources && addSourceLabel !== "" ? ", " + addSourceLabel : "")

  onAddMetricChanged: {
    addStyle = "graph"
    addSource = ""
  }

  readonly property color dim: Qt.darker(foreground, 1.4)

  width: parent ? parent.width : implicitWidth
  spacing: Style.spacing.lg

  function cloneItems(): var {
    var out = []
    for (var i = 0; i < items.length; i++) {
      var copy = {}
      for (var key in items[i]) copy[key] = items[i][key]
      out.push(copy)
    }
    return out
  }

  function replaceItem(index: int, patch: var): void {
    var next = cloneItems()
    if (!next[index]) return
    for (var key in patch) {
      if (patch[key] === "" || patch[key] === null) delete next[index][key]
      else next[index][key] = patch[key]
    }
    itemsEdited(next)
  }

  function moveItem(index: int, delta: int): void {
    var next = cloneItems()
    var target = index + delta
    if (!next[index] || target < 0 || target >= next.length) return
    var moved = next.splice(index, 1)[0]
    next.splice(target, 0, moved)
    itemsEdited(next)
  }

  function removeItem(index: int): void {
    var next = cloneItems()
    if (!next[index]) return
    next.splice(index, 1)
    itemsEdited(next)
  }

  function addItem(): void {
    var next = cloneItems()
    var item = { metric: addMetric, style: addStyle }
    if (addSource !== "") item.source = addSource
    next.push(item)
    itemsEdited(next)
  }

  function sourceOptionsFor(metricId: string): var {
    var sampler = service ? service.samplerFor(metricId) : null
    var options = sampler ? sampler.sourceOptions : []
    return options.length > 0 ? options : [{ value: "", label: "Default" }]
  }

  PanelSectionHeader {
    text: "Bar items"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Text {
    visible: root.items.length === 0
    textFormat: Text.PlainText
    text: "Nothing in the bar yet. Add a metric below."
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  Repeater {
    model: root.items
    Column {
      id: row
      required property var modelData
      required property int index
      readonly property var metric: Metrics.metric(modelData.metric)

      width: parent.width
      spacing: Style.spacing.sm

      Item {
        width: parent.width
        implicitHeight: Math.max(nameText.implicitHeight, actions.implicitHeight)

        Text {
          id: nameText
          anchors.left: parent.left
          anchors.right: actions.left
          anchors.rightMargin: Style.spacing.md
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: (row.metric ? row.metric.glyph + "  " + row.metric.name : row.modelData.metric)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        Row {
          id: actions
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.spacing.xs

          PanelActionButton {
            iconText: "↑"
            tooltipText: "Move left"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.moveItem(row.index, -1)
          }
          PanelActionButton {
            iconText: "↓"
            tooltipText: "Move right"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.moveItem(row.index, 1)
          }
          PanelActionButton {
            iconText: "✕"
            tooltipText: "Remove"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.removeItem(row.index)
          }
        }
      }

      Row {
        spacing: Style.spacing.sm

        Dropdown {
          showLabel: false
          implicitWidth: Style.space(112)
          foreground: root.foreground
          fontFamily: root.fontFamily
          options: Metrics.stylesFor(row.modelData.metric)
          value: row.modelData.style
          onChanged: function(next) { root.replaceItem(row.index, { style: next }) }
        }
        Dropdown {
          visible: row.metric ? row.metric.hasSources : false
          showLabel: false
          implicitWidth: Style.space(196)
          foreground: root.foreground
          fontFamily: root.fontFamily
          options: root.sourceOptionsFor(row.modelData.metric)
          value: row.modelData.source || ""
          onChanged: function(next) { root.replaceItem(row.index, { source: next }) }
        }
      }

      PanelSeparator {
        visible: row.index < root.items.length - 1
        foreground: root.foreground
        strength: 0.08
      }
    }
  }

  PanelSeparator { foreground: root.foreground }

  PanelSectionHeader {
    text: "Add to the bar"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: "Pick a metric, how it should look, and what it reads from. The same metric can be added more than once."
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  Dropdown {
    label: "Metric"
    implicitWidth: parent.width
    foreground: root.foreground
    fontFamily: root.fontFamily
    options: Metrics.metricOptions()
    value: root.addMetric
    onChanged: function(next) { root.addMetric = next }
  }

  Dropdown {
    label: "Style"
    implicitWidth: parent.width
    foreground: root.foreground
    fontFamily: root.fontFamily
    options: Metrics.stylesFor(root.addMetric)
    value: root.addStyle
    onChanged: function(next) { root.addStyle = next }
  }

  Dropdown {
    visible: root.addMetricInfo ? root.addMetricInfo.hasSources : false
    label: "Source"
    implicitWidth: parent.width
    foreground: root.foreground
    fontFamily: root.fontFamily
    options: root.sourceOptionsFor(root.addMetric)
    value: root.addSource
    onChanged: function(next) { root.addSource = next }
  }

  Button {
    text: "Add " + root.addSummary
    iconText: "+"
    bordered: true
    foreground: root.foreground
    fontFamily: root.fontFamily
    onClicked: root.addItem()
  }

  PanelSeparator { foreground: root.foreground }

  PanelSectionHeader {
    text: "Sampling"
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  NumberField {
    label: "Interval (ms)"
    value: root.intervalMs
    from: Metrics.LIMITS.intervalMs.min
    to: Metrics.LIMITS.intervalMs.max
    stepSize: 250
    foreground: root.foreground
    fontFamily: root.fontFamily
    onModified: function(next) { root.intervalEdited(next) }
  }

  NumberField {
    label: "History (samples)"
    value: root.historyLength
    from: Metrics.LIMITS.historyLength.min
    to: Metrics.LIMITS.historyLength.max
    stepSize: 10
    foreground: root.foreground
    fontFamily: root.fontFamily
    onModified: function(next) { root.historyEdited(next) }
  }

  Item {
    width: parent.width
    implicitHeight: Style.spacing.controlHeight

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "Icons in the bar"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    ToggleSwitch {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: root.showIcons
      foreground: root.foreground
      onToggled: root.showIconsEdited(!root.showIcons)
    }
  }
}
