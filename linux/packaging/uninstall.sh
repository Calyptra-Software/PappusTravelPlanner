#!/usr/bin/env sh
# Undo install.sh for the current user. Nothing else is touched: the trips are
# in your database file, which this never looks at.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
template="$(ls "$here"/*.desktop.in 2>/dev/null | head -1 || true)"
if [ -z "$template" ]; then
  echo "error: run this from the installed folder (it must hold a .desktop.in file)" >&2
  exit 1
fi
app_id="$(basename "$template" .desktop.in)"
case "$app_id" in
  *.ci) command_name="pappus-ci" ;;
  *) command_name="pappus" ;;
esac

prefix="${PAPPUS_PREFIX:-$HOME/.local}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
opt_dir="$prefix/opt/$app_id"
bin_link="$prefix/bin/$command_name"

rm -f "$data_home/applications/$app_id.desktop"
rm -f "$data_home/icons/hicolor/192x192/apps/$app_id.png"
# Only if it still points into this install: a symlink someone re-pointed by
# hand is theirs, not ours.
if [ -L "$bin_link" ] && [ "$(readlink "$bin_link")" = "$opt_dir/pappus" ]; then
  rm -f "$bin_link"
fi
rm -rf "$opt_dir"

echo "Removed $app_id. Your database file was not touched."
