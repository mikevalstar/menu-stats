# Metrics

Every sampler publishes the same shape so the strip and the flyout do not
care which metric they show. A sampler exposes `data`, an object keyed by
source id, reassigned on every tick so bindings refresh. Source `""` is the
default (all interfaces, the primary GPU, the main temperature). Each entry
has:

- `level`: 0 to 1 for level metrics, or the current rate scaled against the
  history maximum for rate metrics. Drives the meter style.
- `text`: the short value for the text style, the tooltip, and the hero
  pill.
- `series`: one or two arrays of history, newest last, zero-filled to the
  history length from the first sample. Drives the graphs.
- `barLines`: optional two short strings for the text style, shown stacked.
- `usage`: optional list of `{ label, fraction, text }` for filesystem
  bars; disk provides it.
- `bars`: optional per-part levels, used by CPU for cores.
- `meta`: a one-line description for the hero, such as the device name.
- `details`: rows of `{ label, value }` for the page.

Samplers also expose `sourceOptions`, the list the config page offers for
that metric, and `available`, false when the metric cannot be read here.

| Metric | Reads | Level | Sources |
|---|---|---|---|
| CPU ([CpuSampler.qml](../samplers/CpuSampler.qml), [Cpu.js](../lib/Cpu.js)) | `/proc/stat`, `/proc/loadavg`, `/proc/cpuinfo`, `scaling_cur_freq` | busy fraction since the last tick, per core too | none |
| Memory ([MemorySampler.qml](../samplers/MemorySampler.qml), [Memory.js](../lib/Memory.js)) | `/proc/meminfo` | `MemTotal - MemAvailable` over `MemTotal` | none |
| GPU ([GpuSampler.qml](../samplers/GpuSampler.qml), [Gpu.js](../lib/Gpu.js)) | `/sys/class/drm/card*/device/` for AMD, `nvidia-smi` for NVIDIA | busy percent | each card found |
| Network ([NetworkSampler.qml](../samplers/NetworkSampler.qml), [Network.js](../lib/Network.js)) | `/proc/net/dev` | bytes per second down and up | all physical, or one interface |
| Disk ([DiskSampler.qml](../samplers/DiskSampler.qml), [Disk.js](../lib/Disk.js)) | `/proc/diskstats` | bytes per second read and written | all whole disks, or one |
| Sensor ([SensorSampler.qml](../samplers/SensorSampler.qml), [Sensors.js](../lib/Sensors.js)) | `/sys/class/hwmon/*/{name,temp*,fan*}` | temperature over 100°C, fan speed over 6000 rpm | every temperature and fan channel |
| Processes ([ProcessSampler.qml](../samplers/ProcessSampler.qml), [Processes.js](../lib/Processes.js)) | every `/proc/<pid>/stat` in one `cat` | CPU share of the whole machine since the last read, resident memory | none; sorted by CPU on the CPU page, by memory on the memory page |

The process table is page-only: it samples every two seconds while a CPU
or memory page is open and stops when it closes. The disk sampler adds a
`usage` list of mounted filesystems from one `df` call every 30 seconds
while a disk item is in the strip.

## Decisions

- Subprocesses are allowed only where the kernel gives no file to read,
  and each runs only while something is looking: `nvidia-smi` per tick for
  NVIDIA utilisation, `df` every 30 seconds for free space, and one `cat`
  of every `/proc/<pid>/stat` every two seconds for the process table.
  AMD GPUs are read from sysfs. Intel reports only its frequency.
- "All interfaces" sums physical interfaces only. Tunnels, bridges, and
  container interfaces carry traffic that already crossed a physical one.
- "All disks" sums whole devices (`nvme*n*`, `sd*`, `vd*`, `mmcblk*`), not
  partitions or device-mapper targets, for the same reason.
- Sensor ids are `chip/label`, with `#2`, `#3` appended when a machine has
  several of the same chip. hwmon directory numbers are not stable across
  boots, so they are never part of the id.
- Directory listing uses `Qt.labs.folderlistmodel`, which ships with Qt and
  loads inside the shell. It is the only way to enumerate sysfs from QML
  without a subprocess.
