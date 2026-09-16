---
name: verify-live
description: Install the bar drawer into the running omarchy-shell and check that it loaded without errors. Use after changing Drawer.qml, Shelf.qml, DrawerModel.js, or manifest.json, or when asked whether the plugin works.
---

Verify the plugin in the live shell. Never change the bar layout here: no `--enable`, no `omarchy bar`, no `omarchy-bar-drawer add/remove`.

1. From the repo root, run `./install.sh`. If validation fails, stop and report the error.
2. Confirm the shell sees the plugin:
   `omarchy-shell shell listPlugins | jq -c '.[] | select(.id=="io.github.sykesthelord.bar-drawer")'`
   `enabled: false` only means no drawer is on the bar. Report it; don't enable it.
3. Find the omarchy-shell instance: `quickshell list --all`, taking the instance whose config path is `/usr/share/omarchy/shell/shell.qml`.
4. Read its log for drawer problems:
   `quickshell log -i <instance> --tail 400 | grep -iE "bar-drawer|Drawer\.qml|Shelf\.qml|DrawerModel|TypeError|ReferenceError" | grep -v "Local plugin changed"`
   Warnings that name other plugins' files are not this plugin's problem; leave them out.
5. Only if the user asks for an interaction test: `omarchy-shell shell toggle io.github.sykesthelord.bar-drawer '{}'` opens the first drawer on screen. Run it again to close it, then re-check the log.

Report in a few lines: whether install and validation passed, whether the plugin is enabled, and every drawer-related log line, quoted exactly.
