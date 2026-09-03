# The bar widget

One plugin, one bar entry, a strip of metric items inside it, and a flyout
that shows a page per item plus a config page. Modelled on iStat Menus: the
bar is the glanceable part, the flyout is the detail, and the user decides
what is in the strip.

## Files

- [manifest.json](../manifest.json): plugin id `valstar.menu-stats`. Kinds
  `service` and `bar-widget`, so one sampler serves every bar copy.
- [Widget.qml](../Widget.qml): the bar entry. Owns settings, the strip, and
  the flyout, and pushes sampling config to the service.
- [StatsService.qml](../StatsService.qml): the shared sampler host. One timer, one
  sampler per metric, loaded once per shell no matter how many monitors.
- [samplers/](../samplers/): one file per metric, each reading its `/proc`
  or `/sys` files and publishing a uniform view. See [metrics.md](metrics.md).
- [lib/](../lib/): pure JavaScript. Parsers per metric, the metric
  catalogue in [Metrics.js](../lib/Metrics.js), number formatting in
  [Format.js](../lib/Format.js), and history trimming in
  [History.js](../lib/History.js).
- [dev/harness.sh](../dev/harness.sh): runs the widget and service outside
  the shell with a mock bar. See [quickshell.md](quickshell.md).
- [ui/](../ui/): the pieces the widget is drawn from. [StripItem.qml](../ui/StripItem.qml)
  renders one bar item in its chosen style, [Sparkline.qml](../ui/Sparkline.qml)
  and [Meter.qml](../ui/Meter.qml) are the two graph primitives,
  [MetricPage.qml](../ui/MetricPage.qml) and [ConfigPage.qml](../ui/ConfigPage.qml)
  are the flyout pages.

## In the bar

The strip is a row of items from the `items` setting. Each item is a metric,
a style, and optionally a source (an interface, a disk, a GPU, a sensor).
Styles:

- `graph`: a sparkline of recent history. Rate metrics draw two series,
  down or read filled, up or write as a line.
- `meter`: a thin vertical level bar. Rate metrics show two.
- `text`: the current value as fixed-width text.

An optional glyph sits before each item. Left click opens the flyout on that
item's page. Right click opens the config page. The item whose page is open
uses the bar's active colour, like the first-party widgets.

## The flyout

A tab row at the top with one glyph per strip item and a gear on the right.
Below it, either a metric page or the config page.

A metric page shows a hero (glyph, name, current value pill, a meta line
such as the processor model), a large history graph, per-core meters for
CPU, and a list of detail rows the sampler provides. The sensors page lists
every sensor found, not only the one in the bar.

The config page is where iStat's preferences live: the list of strip items
with style and source pickers and move and remove buttons, an add row, and
the sampling interval, history length, and icon toggle. Every change
persists immediately. See [settings.md](settings.md).

Escape on the config page returns to the metric page; Escape there closes.
Tab and Shift+Tab switch to neighbouring bar panels.

## Sampling

The service samples only the metrics that appear in the strip, on one
shared interval, and keeps history for each at the configured length.
Enumeration of sources (interfaces, disks, GPUs, sensors) happens once at
load so the config page can offer them without turning sampling on.

Each bar copy is a full widget instance, one per monitor, but they all read
the same service so the files are read once per tick.

## Not doing yet

- Keyboard cursor navigation inside the flyout. Mouse only, apart from
  Escape and Tab.
- Top-process lists. They need `/proc/<pid>` walks and are a later step.
- Disk space. It needs `statfs`, which no `/proc` file gives, so it waits
  for a decision on a slow `df` subprocess.
