# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

An Omarchy shell (Quickshell) bar-widget plugin, id `io.github.sykesthelord.bar-drawer`. There is no build step and no test suite; the running shell is the test environment.

## Code style

- QML and JS use 2-space indentation, matching Omarchy's shell source. Do not run `qmlformat` — it rewrites files to Qt's 4-space style.
- `qmllint` exits 0 without reporting anything on this code (the `qs.*` imports only exist inside omarchy-shell), so a clean lint proves nothing. Check the live shell log instead (see `/verify-live`).

## Host bar internals

The drawer relies on undocumented parts of the built-in bar, not a public plugin API: `barWidgetRegistry`, `pluginBarApiFor`, `activePopout`/`requestPopout`, `pluginBarApis`, and the `tooltipTarget`/`tooltipText`/`tooltipShown` state. Before changing how the drawer uses any of them, read the current source in `/usr/share/omarchy/shell/` (`plugins/bar/Bar.qml`, `shell.qml`, `services/PluginRegistry.qml`, `Ui/KeyboardPanel.qml`, `Ui/PopupCard.qml`). Read that tree freely; never edit it.

- Third-party widgets are handed a scoped facade, not the Bar root. `DrawerModel.findHostBar` reaches the root through a built-in widget on the same bar window.
- An installed plugin loads only if its id appears in `shell.json` (`bar.layout` or `plugins[]`). Ids inside a drawer's `items` don't count, which is why the CLI writes `plugins[]` entries.
- `Shelf.qml` spans from the screen edge across the bar on purpose: child `KeyboardPanel`s position themselves from their anchor window's height.

## Installing and testing

- `./install.sh` validates the manifest, copies files to `~/.config/omarchy/plugins/io.github.sykesthelord.bar-drawer/`, and rescans plugins. The shell rejects symlinked plugin folders, so it copies an explicit file list: add any new file to that list.
- Validate the manifest alone with `omarchy plugin validate .`.
- Lint the scripts with `shellcheck install.sh bin/omarchy-bar-drawer`.
- Test `bin/omarchy-bar-drawer` against a scratch copy, never the real config: `OMARCHY_SHELL_CONFIG=<copy> OMARCHY_BAR_DRAWER_NO_RELOAD=1 bin/omarchy-bar-drawer ...`.
- `install.sh --enable`, `omarchy plugin enable/disable`, `omarchy bar ...`, and the CLI's `add`/`remove` all change the user's live bar layout in `~/.config/omarchy/shell.json`. Ask before running them.
