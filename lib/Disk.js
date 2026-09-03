.pragma library

var SECTOR_BYTES = 512

// Whole physical devices only: partitions, device-mapper, zram, and loop
// devices would double count the same bytes.
function isWholeDisk(name) {
  return /^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|mmcblk\d+)$/.test(name)
}

// /proc/diskstats sectors read and written per whole disk.
function parseDiskstats(text) {
  var lines = String(text || "").split("\n")
  var out = {}
  for (var i = 0; i < lines.length; i++) {
    var fields = lines[i].trim().split(/\s+/)
    if (fields.length < 10) continue
    var name = fields[2]
    if (!isWholeDisk(name)) continue
    out[name] = {
      read: (parseInt(fields[5], 10) || 0) * SECTOR_BYTES,
      write: (parseInt(fields[9], 10) || 0) * SECTOR_BYTES
    }
  }
  return out
}

// Bytes per second per disk between two snapshots, plus "" for the total.
function ratesBetween(previous, next, seconds) {
  var out = { "": { read: 0, write: 0 } }
  if (!(seconds > 0)) return out
  for (var name in next) {
    if (!previous[name]) continue
    var read = Math.max(0, (next[name].read - previous[name].read) / seconds)
    var write = Math.max(0, (next[name].write - previous[name].write) / seconds)
    out[name] = { read: read, write: write }
    out[""].read += read
    out[""].write += write
  }
  return out
}

function sourceOptions(snapshot) {
  var names = []
  for (var name in snapshot) names.push(name)
  names.sort()
  var out = [{ value: "", label: "All disks" }]
  for (var i = 0; i < names.length; i++) out.push({ value: names[i], label: names[i] })
  return out
}

// `df -B1 --output=source,target,fstype,size,used` rows for real
// filesystems. Bind mounts and btrfs subvolumes repeat the same device, so
// each source keeps only its shortest mount point.
var PSEUDO_FS = /^(tmpfs|devtmpfs|efivarfs|overlay|squashfs|proc|sysfs|cgroup2?|ramfs|autofs|fuse\.portal|fuse\.gvfsd-fuse|binfmt_misc|debugfs|tracefs|configfs|securityfs|pstore|bpf|hugetlbfs|mqueue|devpts|nsfs)$/

function parseDf(text) {
  var lines = String(text || "").split("\n")
  var bySource = {}
  for (var i = 1; i < lines.length; i++) {
    var fields = lines[i].trim().split(/\s+/)
    if (fields.length < 5) continue
    var source = fields[0], target = fields[1], fstype = fields[2]
    var size = parseInt(fields[3], 10) || 0
    var used = parseInt(fields[4], 10) || 0
    if (source.indexOf("/dev/") !== 0 || PSEUDO_FS.test(fstype) || size <= 0) continue
    if (bySource[source] && bySource[source].target.length <= target.length) continue
    bySource[source] = { source: source, target: target, fstype: fstype, size: size, used: used }
  }
  var out = []
  for (var key in bySource) out.push(bySource[key])
  out.sort(function(a, b) { return a.target < b.target ? -1 : (a.target > b.target ? 1 : 0) })
  return out
}
