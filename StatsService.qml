import QtQuick
import Quickshell
import "samplers"

// Shared sampler host, loaded once per shell. Bar widgets push their
// sampling config here and read sampler data back; a second monitor's bar
// copy costs nothing extra.
Scope {
  id: root

  property var shell: null
  property var manifest: null

  property int intervalMs: 1000
  property int historyLength: 60
  property var needed: ({})

  readonly property CpuSampler cpu: CpuSampler {
    enabled: root.needed.cpu === true
    historyLength: root.historyLength
  }
  readonly property MemorySampler memory: MemorySampler {
    enabled: root.needed.memory === true
    historyLength: root.historyLength
  }
  readonly property GpuSampler gpu: GpuSampler {
    enabled: root.needed.gpu === true
    historyLength: root.historyLength
  }
  readonly property NetworkSampler network: NetworkSampler {
    enabled: root.needed.network === true
    historyLength: root.historyLength
  }
  readonly property DiskSampler disk: DiskSampler {
    enabled: root.needed.disk === true
    historyLength: root.historyLength
  }
  readonly property SensorSampler sensor: SensorSampler {
    enabled: root.needed.sensor === true
    historyLength: root.historyLength
  }

  function configure(intervalMs: int, historyLength: int, needed: var): void {
    root.intervalMs = intervalMs
    root.historyLength = historyLength
    root.needed = needed || {}
  }

  function samplerFor(metric: string): var {
    switch (metric) {
      case "cpu": return cpu
      case "memory": return memory
      case "gpu": return gpu
      case "network": return network
      case "disk": return disk
      case "sensor": return sensor
    }
    return null
  }

  Timer {
    interval: root.intervalMs
    running: true
    repeat: true
    onTriggered: {
      var samplers = [root.cpu, root.memory, root.gpu, root.network, root.disk, root.sensor]
      for (var i = 0; i < samplers.length; i++) if (samplers[i].enabled) samplers[i].sample()
    }
  }
}
