# Coding against Quickshell and the Omarchy shell

## What Quickshell is

[Quickshell](https://quickshell.org/) is a Qt/QML toolkit for building
desktop shells on Wayland. Omarchy runs one long-lived Quickshell process,
`omarchy-shell`, and everything visible (bar, popups, lock screen) is a plugin
loaded into it. Our plugin is QML plus a little JavaScript; there is no build
step and no separate process.

The installed version on this machine is Quickshell 0.3.1, so read the
`v0.3.0` docs, not `master`.

## Read these first

Quickshell:

- [Introduction](https://quickshell.org/docs/v0.3.0/guide/introduction) and
  [QML language](https://quickshell.org/docs/v0.3.0/guide/qml-language): the
  guide is short and assumes no Qt background.
- [Type index](https://quickshell.org/docs/v0.3.0/types): every Quickshell
  type. The ones we use:
  - [FileView](https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/FileView):
    asynchronous file reads. `reload()` re-reads, `loaded` fires when text is
    ready, `text()` returns it. This is how we sample `/proc` and `/sys`.
  - [PanelWindow](https://quickshell.org/docs/v0.3.0/types/Quickshell/PanelWindow)
    and [WlrLayershell](https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/WlrLayershell):
    the layer-shell surface the Omarchy flyouts are built on.
  - [IpcHandler](https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/IpcHandler):
    what `omarchy-shell shell toggle <id>` calls into.
  - [Process](https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/Process):
    only if a metric cannot be read from a file. Avoid.

Qt, for the QML itself:

- [QML syntax basics](https://doc.qt.io/qt-6/qtqml-syntax-basics.html)
- [JavaScript in QML](https://doc.qt.io/qt-6/qtqml-javascript-resources.html):
  `.js` libraries with `.pragma library`, which is how [Cpu.js](../Cpu.js)
  is loaded.
- [QML value types](https://doc.qt.io/qt-6/qtqml-typesystem-valuetypes.html):
  what can be declared as a typed property instead of `var`.

Icons are Nerd Font glyphs; find them on the
[Nerd Fonts cheat sheet](https://www.nerdfonts.com/cheat-sheet).

## How the Omarchy shell hosts a bar widget

The authoritative contract is on disk, not online:

- `/usr/share/omarchy/shell/README.md`: manifest schema, IPC surface,
  `shell.json` layout.
- `/usr/share/omarchy/shell/plugins/bar/README.md`: the `bar` object injected
  into widgets and the settings schema.
- `/usr/share/omarchy/shell/Ui/`: the `qs.Ui` module. Widgets are assembled
  from these, not from raw Qt controls.
- `/usr/share/omarchy/shell/Commons/`: the `qs.Commons` module holding the
  `Style` and `Color` singletons.

Source is at [basecamp/omarchy](https://github.com/basecamp/omarchy) under
`shell/`.

What a popup widget is made of, as the first-party ones do it:

- The root is `Panel` from `qs.Ui`. It owns the open/closed state, exposes
  `open()`, `close()`, `toggle()`, `opened`, and registers an `IpcHandler`
  for `ipcTarget`. The bar looks for exactly those members when it summons a
  panel.
- The bar slot is a `BarIconButton`. It sizes itself to the bar, follows the
  theme, and emits `pressed(button)`.
- The flyout is a `KeyboardPanel` anchored to that button. It handles
  positioning for all four bar edges, outside-click dismissal, keyboard
  focus, and the one-popup-at-a-time coordinator. `PopupCard` exists too but
  first-party panels use `KeyboardPanel`.
- Content goes inside a `PanelKeyCatcher` so Escape closes and Tab switches
  panels, built from `PanelHero`, `PanelSeparator`, `PanelSectionHeader`,
  and plain `Text`.

Theme and scale come from the singletons: `Style.font.*` for sizes,
`Style.space(px)` for any dimension, `Style.spacing.*` for standard gaps,
`Color.*` and `bar.barForeground` for colours. Never hard-code pixels or hex.

## Sampling approach

A `FileView` per `/proc` or `/sys` file and one `Timer` that calls
`reload()` on it. Deltas are computed in a `.js` library from the previous
snapshot. This costs one file read per second per metric and nothing else.
Files that only need reading once, like `/proc/cpuinfo`, have no timer.

## Development loop

The repo is symlinked into the user plugin directory, so saving a file is
the deploy step:

```
ln -s "$PWD" ~/.config/omarchy/plugins/valstar.menu-stats
omarchy-shell shell rescanPlugins
omarchy plugin enable valstar.menu-stats --section center
```

The validator refuses symlinks anywhere under the folder, and the shallow
clones in `inspiration/` contain a couple, so validate an export that leaves
that folder out:

```
rsync -a --exclude inspiration --exclude .git ./ /tmp/menu-stats-export/
omarchy plugin validate /tmp/menu-stats-export
```

Saved QML hot-reloads. When a widget goes blank, the error is in the shell
log:

```
qs log -p /usr/share/omarchy/shell -t 100
```

Open and close the flyout without touching the mouse:

```
omarchy-shell shell summon valstar.menu-stats
omarchy-shell shell hide valstar.menu-stats
```

or restart the shell outright with `omarchy-restart-shell`.

## Gotchas learned so far

- `qs.Ui` and `qs.Commons` only resolve inside `omarchy-shell`. The widget
  cannot be run standalone with `qs -p`; preview it in the real bar.
- `reload()` on a `FileView` is asynchronous. Read `text()` inside
  `onLoaded`, never right after calling `reload()`.
- The first sample of a delta metric has nothing to compare against.
  Report nothing until the second sample rather than a fake zero spike.
- Reassigning a JS array property re-creates every `Repeater` delegate.
  Fine for a handful of core meters; the history graphs will draw with
  `Canvas` instead.
