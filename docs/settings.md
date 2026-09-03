# Settings

All state lives inline on the widget's entry in `~/.config/omarchy/shell.json`,
the only place the shell persists per-widget settings. The widget writes it
through the shell's `updateEntryInline`, the same path the first-party
panels use, so `omarchy bar set` and hand edits stay in sync with the
config page.

The bar does not merge manifest defaults into the entry, so the defaults
live in [Metrics.js](../lib/Metrics.js) and are applied when a key is
missing.

```json
{
  "id": "valstar.menu-stats",
  "intervalMs": 1000,
  "historyLength": 60,
  "showIcons": true,
  "items": [
    { "metric": "cpu", "style": "graph" },
    { "metric": "memory", "style": "meter" },
    { "metric": "network", "style": "graph", "source": "" }
  ]
}
```

- `intervalMs`: sampling period, 250 to 10000.
- `historyLength`: samples kept per series, 20 to 600. Also the width in
  samples of every graph.
- `showIcons`: glyph before each strip item.
- `items`: the strip, in order. `metric` is one of `cpu`, `memory`, `gpu`,
  `network`, `disk`, `sensor`. `style` is `graph`, `meter`, or `text`.
  `source` is optional and metric-specific; an unknown source falls back
  to the default. Unknown metrics or styles are dropped on read.

The manifest schema exposes the three scalar keys for the shell's own
settings form. `items` is only editable from the flyout's config page.
