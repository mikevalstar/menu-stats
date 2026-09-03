# Publishing

The plugin is listed on the [Omarchy plugin marketplace](https://plugins.omarchy.org).
The marketplace validates the repository at an exact commit and runs a
static security baseline over it. This page records what that requires so
ordinary edits do not break the listing.

Source of truth: the marketplace's [SUBMISSION.md](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md)
and [SECURITY.md](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SECURITY.md).

## What the repository must keep

- [manifest.json](../manifest.json) at the root with `schemaVersion: 1`,
  a lowercase `id` outside `omarchy.*`, and `id`, `name`, `version`,
  `author`, `description`, `kinds`, `entryPoints`. `version` and `author`
  are shown on the listing. The `id` is permanent once listed; changing it
  means a new listing and orphans every installed copy.
- A root [README.md](../README.md) with install and removal instructions
  and a list of external dependencies.
- A root [LICENSE](../LICENSE) file. The manifest's `license` field must
  agree with it.
- A root [preview.png](../preview.png), optional but used for the card and
  detail images. The marketplace resizes it; a composite of the bar strip
  and a page or two is enough. Regenerate it when the look changes.
- No symlinks anywhere in the tree. `inspiration/` is git-ignored for this
  reason as well as for licensing.

## What the security baseline looks at

It scans `.qml`, `.js`, `.sh`, `.py`, `.toml`, `.yml`, `.service`, and
similar files, anything under `bin/` or `scripts/`, any file whose name
contains install, setup, or uninstall, and fenced code blocks in the root
README tagged `sh`, `bash`, or `shell` outside sections about development
or testing. `docs/` and `tests/` are skipped.

A clean result ("passed") lists as Verified without a maintainer weighing
in. Anything below drops the listing to review-required or blocks it:

- `sudo`, `pkexec`, `systemctl`, or `systemd-run` anywhere in scanned
  files, including prose in the README. Stating that they are not required
  is fine; the scanner recognises the negation.
- A `git clone`, `curl`, or `wget` of any repository in a scanned shell
  block, even our own. Keep the README's install block on
  `omarchy plugin add` and leave the by-hand path as prose.
- Package manager invocations such as `pacman -S` or `npm install`.
- Files whose names contain install, setup, or uninstall.
- Bundled executables or sudoers files.

This plugin reads `/proc` and `/sys` and runs `nvidia-smi` and `df` as the
shell user. None of that is a flagged capability. Keep it that way: a
feature that needs privilege belongs behind a documented opt-in, not in the
plugin.

## Before submitting or updating

1. `omarchy plugin validate` on an export without `inspiration/`, as in
   [quickshell.md](quickshell.md).
2. Run the marketplace's own scanner. Clone
   `omacom/omarchy-plugin-marketplace` somewhere outside this repo, build a
   file list from `git ls-files` filtered with `isSecurityScanPath` from
   `scripts/security-baseline-scope.mjs`, and pass it to
   `buildSecurityBaseline` from `scripts/security-baseline-analysis.mjs`
   with our repository slug and any 40-character SHA. The outcome must be
   `passed` with empty findings and capabilities. A quicker smell test is
   `rg -n 'sudo|pkexec|systemctl|git clone|curl|wget' --glob '!inspiration/**'`,
   which should find nothing outside this page.
3. Bump `version` in the manifest and push. The listing tracks the branch
   head but verification is bound to the reviewed commit, so an update is
   submitted through the marketplace's plugin verification form with the
   full commit SHA.

Listing metadata: category `Widgets`, tags `bar`, `system`, `quickshell`.
