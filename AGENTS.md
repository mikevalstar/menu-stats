# Agent guide for menu-stats

Read [README.md](README.md) first. It states the intent; this file states how
to work in the repo. The design of each part lives in [docs/](docs/README.md).

## What this is

An Omarchy shell plugin (Quickshell / QML) that puts an iStat-Menus-style
strip of live graphs in the Omarchy bar for CPU, memory, GPU, network, disk,
and sensors, with a flyout page per item and an in-flyout config page.

## Ground rules

- Documentation first. Update README.md and `docs/` before changing
  behaviour. Docs state intent and goals, and link to code rather than
  restating it.
- Keep it simple. One plugin, no daemons, no polling scripts. Sample `/proc`
  and `/sys` from QML with Quickshell's `FileView` and compute deltas in JS.
  A subprocess is allowed only where the kernel gives no file to read, and
  only while something is looking at the result. The current exceptions are
  listed in [docs/metrics.md](docs/metrics.md).
- Never edit anything under `/usr/share/omarchy/`. Read it freely; it is the
  reference for the plugin contract, the `Style` and `Color` singletons, and
  the first-party widgets.
- Match the shell. Use `Style.font.*`, `Style.space()`, `Style.spacing.*`,
  and `Color.*` so the widget follows the active theme and the user's
  `[font] base-size`. Build from `qs.Ui` components, not raw Qt controls.
- Type the QML: declare property types, annotate function parameters, avoid
  `var` where a concrete type exists, and keep JS helpers in `.pragma
  library` files with clear inputs.

## Where things are

| Path | Role |
|---|---|
| [manifest.json](manifest.json) | Plugin id, kinds `service` and `bar-widget`, settings schema |
| [Widget.qml](Widget.qml) | Bar entry: settings, strip, flyout, navigation, IPC |
| [StatsService.qml](StatsService.qml) | Shared sampler host, one per shell |
| [samplers/](samplers/) | One `Scope` per metric, publishing the shape in [docs/metrics.md](docs/metrics.md) |
| [lib/](lib/) | Pure JS: parsers, formatting, history, the metric catalogue |
| [ui/](ui/) | Sparkline, Meter, StripItem, MetricPage, ConfigPage, DetailRow |
| [dev/harness.sh](dev/harness.sh) | Runs widget and service outside the shell with a mock bar |

## Plugin contract

- `/usr/share/omarchy/shell/README.md` describes the manifest schema, IPC,
  and `shell.json`.
- `/usr/share/omarchy/shell/plugins/bar/README.md` describes bar widgets and
  the `bar` object injected into them.
- `/usr/share/omarchy/shell/Ui/` is `qs.Ui`; `/usr/share/omarchy/shell/Commons/`
  is `qs.Commons`. Both resolve only inside `omarchy-shell` or a config dir
  that symlinks them, which is what the harness does.
- Popup widgets to model on: `plugins/panels/weather/`, `plugins/panels/monitor/`,
  and the installed third-party `~/.config/omarchy/plugins/ilyazar.btop/`,
  which uses the same service-plus-widget split we do.

## How the shell treats this plugin

- The widget root is `Panel` from `qs.Ui`. The bar summons and hides it by
  calling `open()`, `close()`, and reading `opened` on the root, so keep
  those. `Panel` has no `barSize`; read `bar.barSize`.
- The flyout is a `KeyboardPanel` anchored to an item in the bar. Its
  content goes inside a `PanelKeyCatcher` for Escape, Tab, and arrows.
- Strip items extend `WidgetButton` so they register as bar click targets.
  A plain `MouseArea` would not receive clicks while another panel is open.
- Per-widget settings are the fields of the widget's entry in
  `~/.config/omarchy/shell.json`, injected as `settings`. The bar does not
  merge manifest `defaults`; apply defaults in code with `setting()`.
- Settings arrive as Qt lists and maps, not JS arrays and objects.
  `Array.isArray` is false and array methods are missing. Round-trip
  structured values through JSON before use, as `Metrics.normalizeItems` does.
- Persist settings with `bar.shell.updateEntryInline(moduleName, entry)`
  where `entry` is the full entry including `id`. Set `settings` locally
  first so the UI does not wait for the file round trip.
- The service is reached with `bar.shell.serviceFor(moduleName)`. That
  function reads the shell's service table, so a binding on it re-evaluates
  when the service loads. Never call `ensureService` inside that binding; it
  writes the same table and loops. Call it from `onBarChanged`.
- A `service` kind plugin loads once at shell start with `keepLoaded: true`
  and is shared by every bar copy, one per monitor. Widgets push config into
  it and read data back; nothing else should sample.
- Bar widgets have no summon payload and `omarchy-shell shell call` does not
  reach them. Anything a script or hotkey needs goes through the widget's
  own `IpcHandler` on a separate target, here `valstar.menu-stats.nav`.

## QML techniques used here

- Non-visual objects are `Scope` from Quickshell. It takes children like an
  Item without being one, so samplers hold `FileView`s, `Timer`s, and
  `Process`es directly.
- A variable number of readers, one per GPU or sensor channel, is an
  `Instantiator` over a JS array, walked with `count` and `objectAt(i)`.
- Directory listing without a subprocess is `Qt.labs.folderlistmodel`. It
  lists sysfs symlink directories fine. `nameFilters` apply to files only;
  filter directory names in JS.
- `FileView.reload()` is asynchronous. Read `text()` inside `onLoaded`,
  never right after the call. Files that depend on each other, such as a
  sensor value and its label, need explicit ready flags before publishing.
- Samplers publish by reassigning a `var` property with a fresh object each
  tick. Bindings only see whole-property changes, never mutation in place.
  A short `Timer` coalesces a burst of async loads into one publish.
- Delta metrics report nothing until the second sample. Clear the previous
  snapshot when a sampler is disabled so re-enabling does not average over
  the gap.
- Graphs are `Canvas`. Reassigning an array property re-creates every
  `Repeater` delegate, which is fine for a row of meters and wrong for a
  60-sample series.

## Developing and testing

- Install by symlinking the repo into the user plugin dir:
  `ln -s "$PWD" ~/.config/omarchy/plugins/valstar.menu-stats`, then
  `omarchy plugin enable valstar.menu-stats --section center`.
- Bar widget code does not hot-reload. The shell keeps the compiled
  component across plugin rescans and only refreshes manifest metadata, so
  the loop after every edit is `omarchy-restart-shell`, about two seconds.
  The symlink is deliberate: the shell's `inotifywait` watcher does not
  follow it, so saves do not trigger a full plugin reload that would not
  load the change anyway.
- Run `dev/harness.sh` before restarting the live shell. It loads the widget
  and service in a throwaway Quickshell with a mock bar, walks every page,
  and prints QML errors and sampler output. Samplers can also be exercised
  alone: `StatsService.qml` imports nothing shell-specific, so a scratch
  `shell.qml` can `Qt.createComponent` it under plain `qs -p`.
- Never restart or rescan the shell while the screen is locked. Reloading
  plugins recreates the lock service, Quickshell aborts on "Tried to show
  lockscreen surfaces without active lock", and the replacement service
  cannot take a session lock the dead process still holds. The user ends up
  on Hyprland's failsafe and has to clear it by hand.
- Write new files before touching `manifest.json`, and not in parallel with
  it. A manifest change makes the shell load the entry point immediately,
  and Qt 6.11 caches the directory listing: a file it did not see reports
  "File name case mismatch" until the shell restarts, and
  `Qt.clearComponentCache()` does not help.
- Validate the manifest against an export that excludes `inspiration/`; the
  validator rejects symlinks and the reference clones contain some. Commands
  are in [docs/quickshell.md](docs/quickshell.md).
- Shell log: `qs log -p /usr/share/omarchy/shell -t 100`. Filter out the
  "Handler was registered but will not be used" lines; every panel emits
  them because the bar owns the IPC target.
- Visual checks without touching the mouse: `omarchy-shell shell summon
  valstar.menu-stats`, then `quickshell ipc -p /usr/share/omarchy/shell call
  valstar.menu-stats.nav showItem 2` or `showConfig`, then
  `grim -g "X,Y WxH" out.png` and read the image. `wtype` closes the panel
  instead of typing into it, so drive navigation over IPC.
- Test items can be written straight into the widget's entry in shell.json
  with `jq`; the shell watches the file. The user may be clicking the same
  widget while you test, so do not fight over the panel.

## Reference material

`inspiration/` is git-ignored. It holds shallow clones of related plugins and
screenshots of them, indexed in [inspiration/README.md](inspiration/README.md)
with a note on what idea each one contributes. Borrow ideas and MIT-licensed
code from there with attribution; do not vendor whole repos.
