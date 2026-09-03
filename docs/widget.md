# The bar widget

One plugin, one bar slot, one flyout per metric. The current state is the
CPU rough-in; memory and network follow the same shape.

## Files

- [manifest.json](../manifest.json): plugin id `valstar.menu-stats`, kind
  `bar-widget`, default section `center`.
- [Widget.qml](../Widget.qml): the bar icon, the sampler, and the flyout.
- [Cpu.js](../Cpu.js): parsers for `/proc/stat`, `/proc/loadavg`, and
  `/proc/cpuinfo`. Pure functions, text in and plain data out.

## In the bar

A single CPU glyph in the centre section. Left click toggles the flyout.
The glyph lights up in the active colour while the flyout is open, matching
the first-party widgets. Hover shows the current usage as a tooltip.

Goal, not yet built: replace the glyph with an inline history graph and
keep the click behaviour.

## The flyout

Top to bottom:

1. Hero: CPU glyph, the title, the processor model, and the current usage
   as a pill.
2. Cores: one thin meter per logical core, filled from the bottom.
3. Load average and core count.

Goal, not yet built: a scrolling history graph above the core meters, and a
top-processes list below them.

## Sampling

`/proc/stat` is read every second regardless of whether the flyout is open,
because the bar readout will need history. `/proc/loadavg` is read only
while the flyout is open. `/proc/cpuinfo` is read once.

Usage is the busy fraction between two snapshots, where busy is total minus
idle and iowait. That matches what `top` and btop show.

## Not doing

- No helper binaries, no `Process` polling. If a metric needs a subprocess
  it does not belong here.
- No settings schema yet. Sampling interval and history length become
  manifest settings once the graphs exist and there is something to tune.
