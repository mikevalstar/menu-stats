import QtQuick
import Quickshell
import qs.Commons

// Runs the widget and the service outside omarchy-shell with a mock bar.
// Launched by harness.sh, which builds a scratch config dir where `qs.Ui`
// and `qs.Commons` resolve to the installed shell's modules. Surfaces QML
// errors and prints sampler output without touching the live bar.
ShellRoot {
  id: root

  readonly property string pluginDir: Quickshell.env("MENU_STATS_DIR")
  property var service: null
  property var widget: null

  readonly property var mockShell: QtObject {
    function serviceFor(id) { return root.service }
    function ensureService(id) { return root.service }
    function updateEntryInline(id, entry) { console.log("persist", id, JSON.stringify(entry)); return true }
  }

  readonly property var mockBar: QtObject {
    property color barForeground: "#cccccc"
    property color foreground: "#cccccc"
    property color background: "#101010"
    property color urgent: "#ff5555"
    property string fontFamily: "monospace"
    property string position: "top"
    property bool vertical: false
    property int barSize: 26
    property var activePopout: null
    property var clickTargets: []
    property bool foregroundAnimationEnabled: false
    property var shell: root.mockShell
    function showTooltip(target, text) {}
    function hideTooltip(target) {}
    function requestPopout(owner) { activePopout = owner }
    function releasePopout(owner) { if (activePopout === owner) activePopout = null }
    function registerClickTarget(target) {}
    function unregisterClickTarget(target) {}
    function switchPanelFrom(owner, direction) { return false }
    function moduleWidgets(name) { return [] }
    function run(command) { console.log("run", command) }
  }

  Item { id: host; width: 600; height: 26 }

  function load(name) {
    var comp = Qt.createComponent("file://" + pluginDir + "/" + name, Component.PreferSynchronous)
    if (comp.status !== Component.Ready) {
      console.log("LOAD ERROR", name, comp.errorString())
      Qt.quit()
      return null
    }
    return comp
  }

  Component.onCompleted: {
    var serviceComponent = load("StatsService.qml")
    if (!serviceComponent) return
    root.service = serviceComponent.createObject(root)
    var widgetComponent = load("Widget.qml")
    if (!widgetComponent) return
    root.widget = widgetComponent.createObject(host, {})
    root.widget.settings = {
      id: "valstar.menu-stats",
      items: [
        { metric: "cpu", style: "graph" }, { metric: "memory", style: "meter" }, { metric: "gpu", style: "text" },
        { metric: "network", style: "graph" }, { metric: "disk", style: "meter" }, { metric: "sensor", style: "text" }
      ]
    }
    root.widget.bar = root.mockBar
    console.log("widget ready: items=" + root.widget.items.length + " service=" + (root.widget.service !== null))
  }

  function report() {
    var names = ["cpu", "memory", "gpu", "network", "disk", "sensor"]
    for (var i = 0; i < names.length; i++) {
      var sampler = root.service.samplerFor(names[i])
      var view = sampler.data[""]
      console.log(names[i].padEnd(8), "available=" + sampler.available, view ? view.text + "  [" + view.meta + "]" : "no data yet")
    }
    console.log("strip width", Math.round(root.widget.implicitWidth))
  }

  Timer { interval: 2500; running: true; onTriggered: { root.report(); root.widget.openItem(0) } }
  Timer { interval: 3200; running: true; onTriggered: root.widget.showItem(3) }
  Timer { interval: 3800; running: true; onTriggered: root.widget.showItem(5) }
  Timer { interval: 4400; running: true; onTriggered: root.widget.page = "config" }
  Timer { interval: 5200; running: true; onTriggered: { root.widget.close(); root.report(); Qt.quit() } }
}
