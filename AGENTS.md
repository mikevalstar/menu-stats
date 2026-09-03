# Agent guide for menu-stats

Read [README.md](README.md) first. It states the intent; this file states how
to work in the repo.

## What this is

An Omarchy shell plugin (Quickshell / QML) that adds iStat-Menus-style live
graphs for CPU, memory, and network to the Omarchy bar, with a detail panel
per metric.

## Ground rules

- Documentation first. Update README.md, and docs under `docs/` once that
  folder exists, before changing behaviour. Docs state intent and goals, and
  link to code rather than restating it.
- Keep it simple. One plugin, no daemons, no shell scripts polling in a loop.
  Sample `/proc` and `/sys` from QML with Quickshell's `FileView` and compute
  deltas in JS.
- Never edit anything under `/usr/share/omarchy/`. Read it freely; it is the
  reference for the plugin contract, the `Style` and `Color` singletons, and
  the first-party widgets.
- Match the shell. Use `Style.font.*`, `Style.space()`, and `Color.*` so the
  widget follows the active theme and the user's `[font] base-size`.
- Type the QML: declare property types, avoid `var` where a concrete type
  exists, and keep JS helpers in a `.js` library with clear inputs.

## Plugin contract

- `/usr/share/omarchy/shell/README.md` describes the manifest schema and IPC.
- `/usr/share/omarchy/shell/plugins/README.md` lists first-party plugins.
- `/usr/share/omarchy/shell/plugins/bar/README.md` describes bar widgets,
  the `bar` object injected into them, and the `settings` schema.
- First-party widgets to model on live in
  `/usr/share/omarchy/shell/plugins/bar/widgets/`.

## Developing and testing

- Install for development by symlinking the repo into the user plugin dir:
  `ln -s "$PWD" ~/.config/omarchy/plugins/<plugin-id>`.
- Validate the manifest against an export that excludes `inspiration/`; the
  validator rejects symlinks and the reference clones contain some. The
  exact commands are in [docs/quickshell.md](docs/quickshell.md).
- Enable it in the bar with `omarchy plugin enable <plugin-id> --section center`.
- Saved changes hot-reload. If they do not, run
  `omarchy-shell shell rescanPlugins`.
- Check the shell log for QML errors when a widget goes blank:
  `qs log -p /usr/share/omarchy/shell -t 100`.

## Reference material

`inspiration/` is git-ignored. It holds shallow clones of related plugins and
screenshots of them, indexed in [inspiration/README.md](inspiration/README.md)
with a note on what idea each one contributes. Borrow ideas and MIT-licensed
code from there with attribution; do not vendor whole repos.
