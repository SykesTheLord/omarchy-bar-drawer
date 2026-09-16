#!/bin/bash

# Install Bar Drawer into ~/.config/omarchy/plugins and reload shell plugins.
#
#   ./install.sh               copy the plugin and rescan
#   ./install.sh --enable      also put a drawer on the bar
#   ./install.sh --link-cli    also link omarchy-bar-drawer into ~/.local/bin

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ID=$(jq -r .id "$SRC/manifest.json")
DEST="$HOME/.config/omarchy/plugins/$ID"

enable=false
link_cli=false
for arg in "$@"; do
  case $arg in
    --enable) enable=true ;;
    --link-cli) link_cli=true ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

omarchy plugin validate "$SRC"

# The shell refuses symlinked plugin folders, so install a real copy.
mkdir -p "$DEST"
for file in manifest.json Drawer.qml Shelf.qml DrawerModel.js README.md LICENSE; do
  [[ -f $SRC/$file ]] && cp "$SRC/$file" "$DEST/$file"
done
mkdir -p "$DEST/bin"
cp "$SRC/bin/omarchy-bar-drawer" "$DEST/bin/omarchy-bar-drawer"
chmod +x "$DEST/bin/omarchy-bar-drawer"

omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
echo "Installed $ID to $DEST"

if $link_cli; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$DEST/bin/omarchy-bar-drawer" "$HOME/.local/bin/omarchy-bar-drawer"
  echo "Linked omarchy-bar-drawer into ~/.local/bin"
fi

if $enable; then
  omarchy plugin enable "$ID"
fi
