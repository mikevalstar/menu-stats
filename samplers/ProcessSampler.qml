import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/Processes.js" as Processes

// Top processes for the CPU and memory pages. Runs only while one of those
// pages is open, and reads every /proc/<pid>/stat in one `cat` rather than
// one FileView per process.
Scope {
  id: root

  property bool enabled: false
  property int intervalMs: 2000
  property string sortBy: "cpu"
  property int limit: 8
  property int cores: 1
  property var rows: []

  property var previous: null
  property real previousTime: 0

  onEnabledChanged: {
    if (enabled) {
      previous = null
      rows = []
      sample()
    }
  }

  function sample() {
    if (!statProcess.running) statProcess.running = true
  }

  function apply(text: string): void {
    var snapshot = Processes.parseStats(text)
    var now = Date.now()
    if (previous) {
      rows = Processes.topBetween(previous, snapshot, (now - previousTime) / 1000, cores, sortBy, limit)
    }
    previous = snapshot
    previousTime = now
  }

  Timer {
    interval: root.intervalMs
    running: root.enabled
    repeat: true
    onTriggered: root.sample()
  }

  Process {
    id: statProcess
    command: ["sh", "-c", "cat /proc/[0-9]*/stat 2>/dev/null"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
  }
}
