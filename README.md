# Bar Drawer

An Omarchy shell bar widget that holds other bar widgets. It adds a new place
to put plugins: behind one button, either in a **drop-down shelf** that opens
beside the bar, or in an **inline reveal** that slides the widgets out inside
the bar.

Any bar widget works inside a drawer, built-in or installed. Widgets keep
their tooltips, panels and settings, because the drawer loads them from the
bar's own widget registry and hands them the same `bar` object the bar would.

## Install

```bash
./install.sh --enable --link-cli
```

That validates the manifest, copies the plugin to
`~/.config/omarchy/plugins/io.github.sykesthelord.bar-drawer/`, puts a drawer
in the right section of the bar, and links the helper CLI into `~/.local/bin`.

Move it like any other widget:

```bash
omarchy bar move io.github.sykesthelord.bar-drawer --section right --index 0
```

## Filling a drawer

```bash
omarchy-bar-drawer add yeleticc.vpn            # into drawer 0
omarchy-bar-drawer add omarchy.weather --drawer 1
omarchy-bar-drawer list
omarchy-bar-drawer remove yeleticc.vpn         # back onto the bar, before its drawer
```

`add` takes the widget off the bar, keeps its inline settings, and appends its
id to the drawer's `items`. Each command backs up `shell.json` first and
reloads the shell config.

## Configuration

Drawers are ordinary layout entries in `~/.config/omarchy/shell.json`, and
several can sit on one bar:

```json
{
  "id": "io.github.sykesthelord.bar-drawer",
  "mode": "dropdown",
  "trigger": "click",
  "columns": 0,
  "icon": "",
  "label": "",
  "tooltip": "",
  "items": ["yeleticc.vpn", "h-dong.idle", { "id": "omarchy.clock", "format": "HH:mm" }]
}
```

| Key       | Values                   | Default    | Meaning |
|-----------|--------------------------|------------|---------|
| `mode`    | `dropdown`, `inline`     | `dropdown` | Shelf beside the bar, or slide out inside the bar |
| `trigger` | `click`, `hover`         | `click`    | What opens the drawer |
| `columns` | `0`–`12`                 | `0`        | Dropdown only: widgets per row (`0` = one row) |
| `icon`    | any glyph                | chevron    | Button glyph. The default chevron points away from the bar and flips when open |
| `label`   | text                     | empty      | Optional text after the icon |
| `tooltip` | text                     | widget count | Button tooltip |
| `items`   | ids or `{ "id", ...settings }` | `[]` | Widgets in the drawer, in order |

A widget's settings come from its `items` entry first, then from its
`plugins[]` entry, which wins. Widgets that save their own state write to
`plugins[]` while they live in a drawer, so keep settings there.
`omarchy bar set` only edits `bar.layout`, so it cannot reach widgets inside a
drawer.

Each drawer also responds to the shell's panel commands, e.g. a keybinding
running `omarchy-shell shell toggle io.github.sykesthelord.bar-drawer '{}'`.

## Requirements and limits

- **An installed plugin inside a drawer needs a `plugins[]` entry.** The shell
  only loads installed plugins whose id appears somewhere in `shell.json`, and
  `items` does not count. `omarchy-bar-drawer add` writes the entry for you. If
  a widget shows up as `⚠ <id>`, that entry is missing or the plugin failed to
  load.
- **The bar needs at least one built-in `omarchy.*` widget.** Installed
  widgets only get a limited facade, so the drawer reaches the bar through a
  built-in widget on the same bar window. `omarchy.menu`, `omarchy.clock`, and
  `omarchy.tray` all qualify. Without one, the button is dimmed and says so.
- **This relies on bar internals, not a public API.** It uses
  `barWidgetRegistry`, `pluginBarApiFor`, `activePopout`, and the tooltip
  state on the built-in bar. An Omarchy update that changes those can break
  the drawer. It does not work with third-party replacement bars.
- Keybindings that summon a specific widget's panel find the widget through
  the bar layout, so they do not reach a widget inside a drawer.
- While a child's panel is open, a click on the real bar closes that panel
  first, the same way a click outside it would.
- Drawers cannot be nested.

## How it works

- `Drawer.qml` is the bar widget. It finds the Bar root, builds each child
  from `barWidgetRegistry.widgets[id].component`, and injects `bar`,
  `moduleName`, and `settings` the way the bar's own module slot does.
  Built-in children get the Bar root; installed ones get their own scoped
  facade from `pluginBarApiFor(id, id, true)`. The drawer re-injects when the
  bar prunes facades.
- `Shelf.qml` is the drop-down: a `Top`-layer window that spans from the
  screen edge across the bar, masked to its card. Most widget panels are
  `KeyboardPanel`s, which position themselves from the height of their
  anchor's window, so this span makes a child's panel open beyond the shelf
  rather than on top of it. A Hyprland focus grab closes the shelf on an
  outside click. The grab is suspended while a child's panel is open.
- Popout coordination: the drawer claims the bar's single active popout while
  open. It stays open when the popout passes to one of its own children, and
  closes when anything else on the bar opens.
- `DrawerModel.js` holds the pure helpers.
