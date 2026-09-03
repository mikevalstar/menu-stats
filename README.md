# menu-stats

iStat Menus, but for Omarchy.

A shell plugin that puts live system activity in the Omarchy bar: CPU, memory,
network, and later disk, GPU, and sensors. Compact, always-visible readouts in
the bar with real history graphs, and a detail panel on click.

## Goal

On a Mac, iStat Menus gives you a glanceable strip of small graphs in the menu
bar and a rich dropdown per metric. Nothing in the Omarchy ecosystem does the
first half. Every existing plugin shows text or an icon in the bar and hides
the graphs in a popup. This project fills that gap.

## Scope

- Bar widgets that draw sparklines or mini bar graphs inline, one per metric.
- A detail panel per metric with history, breakdowns, and top processes.
- Themed by the active Omarchy theme, sized by the shell's font scale.
- Read `/proc` and `/sys` directly from QML. No helper daemons, no polling
  scripts, nothing running when the panel is closed beyond the bar sampler.
  The one exception is `nvidia-smi` for NVIDIA GPUs, which have no sysfs
  utilisation counter.

## Non-goals

- Replacing the Omarchy bar. This is a plugin for the stock shell.
- Configuration UIs beyond what the plugin manifest schema gives for free.
- Support for shells other than Omarchy's Quickshell shell.

## Status

MVP in progress. A configurable strip of CPU, memory, GPU, network, disk,
and sensor items with sparkline, meter, or text styles, a flyout page per
item, and an in-flyout config page. See [docs/widget.md](docs/widget.md).

Research and reference material is in `inspiration/`, which is git-ignored
and documented in [inspiration/README.md](inspiration/README.md).

## Layout

The plugin follows the Omarchy shell plugin contract: [manifest.json](manifest.json)
declares a `bar-widget` kind and [Widget.qml](Widget.qml) is its entry
point. The authoritative description of that contract is in the installed
Omarchy source at `/usr/share/omarchy/shell/README.md` and
`/usr/share/omarchy/shell/plugins/bar/README.md`.

`docs/` holds the intent for each part and a primer on coding against
Quickshell and the shell; start at [docs/README.md](docs/README.md).
