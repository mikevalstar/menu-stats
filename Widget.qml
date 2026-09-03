import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ui"
import "lib/Metrics.js" as Metrics

// The bar entry: a strip of metric items and the flyout with a page per
// item plus the config page. Sampling lives in StatsService.qml; this file owns
// settings, layout, and navigation. The root is the shell's Panel base so
// the bar can summon, hide, and toggle it over IPC.
Panel {
  id: root
  moduleName: "valstar.menu-stats"
  ipcTarget: moduleName

  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color panelForeground: Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ------------------------------------------------------------ settings

  readonly property var items: Metrics.normalizeItems(setting("items", Metrics.DEFAULT_ITEMS))
  readonly property int intervalMs: Metrics.clampInt(setting("intervalMs", Metrics.LIMITS.intervalMs.fallback), Metrics.LIMITS.intervalMs)
  readonly property int historyLength: Metrics.clampInt(setting("historyLength", Metrics.LIMITS.historyLength.fallback), Metrics.LIMITS.historyLength)
  readonly property bool showIcons: setting("showIcons", true) !== false

  // Merge a patch into this widget's shell.json entry. The shell writes the
  // file, the bar re-reads it, and `settings` comes back through the host.
  // Setting it locally first keeps the UI from lagging that round trip.
  function persist(patch: var): void {
    if (!bar || !bar.shell || typeof bar.shell.updateEntryInline !== "function") return
    var entry = { id: moduleName }
    for (var key in settings) if (key !== "id") entry[key] = settings[key]
    for (var name in patch) entry[name] = patch[name]
    settings = entry
    bar.shell.updateEntryInline(moduleName, entry)
  }

  // ------------------------------------------------------------ service

  // serviceFor reads the shell's service table, so this re-evaluates when a
  // service loads. ensureService must stay out of the binding: it writes
  // that same table, which would make the binding depend on itself.
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null

  onBarChanged: {
    if (bar && bar.shell && !bar.shell.serviceFor(moduleName)
        && typeof bar.shell.ensureService === "function") bar.shell.ensureService(moduleName)
  }

  function samplerFor(metric: string): var {
    return service ? service.samplerFor(metric) : null
  }

  function pushConfig(): void {
    if (!service) return
    service.configure(intervalMs, historyLength, Metrics.neededMetrics(items))
  }

  onServiceChanged: pushConfig()
  onItemsChanged: pushConfig()
  onIntervalMsChanged: pushConfig()
  onHistoryLengthChanged: pushConfig()
  Component.onCompleted: pushConfig()

  // ------------------------------------------------------------ navigation

  property string page: "metric"
  property int pageIndex: 0
  readonly property int safeIndex: Math.max(0, Math.min(pageIndex, items.length - 1))
  readonly property var currentItem: items.length > 0 ? items[safeIndex] : null

  function openItem(index: int): void {
    pageIndex = index
    page = items.length > 0 ? "metric" : "config"
    open()
  }

  function openConfig(): void {
    page = "config"
    open()
  }

  function showItem(index: int): void {
    pageIndex = index
    page = "metric"
  }

  function back(): void {
    if (page === "config" && items.length > 0) page = "metric"
    else close()
  }

  function stepItem(delta: int): void {
    var count = items.length
    if (count === 0 || page !== "metric") return
    showItem((safeIndex + delta + count) % count)
  }

  // Top processes are sampled only while a CPU or memory page is showing.
  readonly property bool wantsProcesses: opened && page === "metric" && currentItem !== null
    && (currentItem.metric === "cpu" || currentItem.metric === "memory")

  Binding {
    target: root.service ? root.service.processes : null
    property: "enabled"
    value: root.wantsProcesses
  }

  Binding {
    target: root.service ? root.service.processes : null
    property: "sortBy"
    value: root.currentItem && root.currentItem.metric === "memory" ? "memory" : "cpu"
  }

  // Hotkey and script surface, separate from the bar's own summon target:
  //   omarchy-shell valstar.menu-stats.nav showItem 2
  //   omarchy-shell valstar.menu-stats.nav showConfig
  IpcHandler {
    target: root.moduleName + ".nav"

    function showItem(index: string): void { root.openItem(parseInt(index, 10) || 0) }
    function showConfig(): void { root.openConfig() }
    function next(): void { root.open(); root.stepItem(1) }
    function previous(): void { root.open(); root.stepItem(-1) }
    function hide(): void { root.close() }
  }

  // ------------------------------------------------------------ strip

  implicitWidth: strip.implicitWidth
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  Row {
    id: strip
    anchors.centerIn: parent
    spacing: 0

    Repeater {
      model: root.items
      StripItem {
        required property var modelData
        required property int index
        bar: root.bar
        item: modelData
        sampler: root.service ? root.service.samplerFor(modelData.metric) : null
        showIcon: root.showIcons
        active: root.opened && root.page === "metric" && root.safeIndex === index
        onPressed: function(button) {
          if (button === Qt.RightButton) root.openConfig()
          else if (root.opened && root.page === "metric" && root.safeIndex === index) root.close()
          else root.openItem(index)
        }
      }
    }

    // With nothing configured the strip still needs something to click.
    BarIconButton {
      visible: root.items.length === 0
      bar: root.bar
      text: "󰒓"
      active: root.opened
      tooltipText: "Menu Stats: nothing configured"
      onPressed: root.openConfig()
    }
  }

  // ------------------------------------------------------------ flyout

  KeyboardPanel {
    id: popup
    anchorItem: strip
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(392))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.back()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { if (dx !== 0) root.stepItem(dx) }
      onTextKey: function(text) {
        if (text === "," || text === "s") root.page = "config"
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.spacing.lg

        Item {
          width: parent.width
          implicitHeight: Math.max(tabs.implicitHeight, gear.implicitHeight)

          Row {
            id: tabs
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xs

            Repeater {
              model: root.items
              Button {
                required property var modelData
                required property int index
                readonly property var metric: Metrics.metric(modelData.metric)
                iconText: metric ? metric.glyph : ""
                tooltipText: metric ? metric.name : ""
                selected: root.page === "metric" && root.safeIndex === index
                foreground: root.panelForeground
                fontFamily: root.fontFamily
                onClicked: root.showItem(index)
              }
            }
          }

          Button {
            id: gear
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒓"
            tooltipText: "Configure"
            selected: root.page === "config"
            foreground: root.panelForeground
            fontFamily: root.fontFamily
            onClicked: root.page = root.page === "config" && root.items.length > 0 ? "metric" : "config"
          }
        }

        PanelSeparator { foreground: root.panelForeground }

        Loader {
          id: pageLoader
          width: parent.width
          sourceComponent: root.page === "config" || root.currentItem === null ? configPage : metricPage
        }
      }
    }
  }

  Component {
    id: metricPage
    MetricPage {
      item: root.currentItem || ({ metric: "cpu", style: "graph" })
      sampler: root.currentItem ? root.samplerFor(root.currentItem.metric) : null
      processes: root.service ? root.service.processes : null
      foreground: root.panelForeground
      fontFamily: root.fontFamily
    }
  }

  Component {
    id: configPage
    ConfigPage {
      items: root.items
      intervalMs: root.intervalMs
      historyLength: root.historyLength
      showIcons: root.showIcons
      service: root.service
      foreground: root.panelForeground
      fontFamily: root.fontFamily
      onItemsEdited: function(next) { root.persist({ items: next }) }
      onIntervalEdited: function(value) { root.persist({ intervalMs: value }) }
      onHistoryEdited: function(value) { root.persist({ historyLength: value }) }
      onShowIconsEdited: function(value) { root.persist({ showIcons: value }) }
    }
  }
}
