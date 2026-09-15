#!/usr/bin/env sh
# Install this folder for the current user, with a menu entry and an icon.
#
#   ./install.sh            install (or reinstall over an earlier one)
#   ./uninstall.sh          undo it
#
# No root, nothing outside $HOME, and the program itself is only copied -- the
# desktop entry is what actually needs installing. Its `Exec=` is rewritten to
# the absolute path of the installed binary rather than left as a bare name,
# because ~/.local/bin is not on every distribution's PATH (and never on the
# session's PATH when it is created after login), and a menu entry that cannot
# find its program is worse than none. The icon has to sit in an icon theme
# directory for `Icon=` to resolve at all.
#
# Everything is derived from what lies beside this script, so the CI build
# installs as itself rather than over the released app: exactly one .desktop
# file is here, and it names both the application id and the icon.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
desktop="$(ls "$here"/*.desktop 2>/dev/null | head -1 || true)"
if [ -z "$desktop" ] || [ ! -x "$here/pappus" ]; then
  echo "error: run this from the unpacked folder (it must hold pappus and a .desktop file)" >&2
  exit 1
fi
app_id="$(basename "$desktop" .desktop)"

# The CI build takes a command name of its own, or its symlink would be the
# one thing of the two installs that could not stand beside the other.
case "$app_id" in
  *.ci) command_name="pappus-ci" ;;
  *) command_name="pappus" ;;
esac

prefix="${PAPPUS_PREFIX:-$HOME/.local}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
# Deliberately not $data_home/$app_id: that is where the app keeps its
# preferences (path_provider keys them by the GTK application id), and the
# program's own files have no business in it.
opt_dir="$prefix/opt/$app_id"
bin_link="$prefix/bin/$command_name"
icon_dir="$data_home/icons/hicolor/192x192/apps"
applications="$data_home/applications"

if [ "$here" = "$opt_dir" ]; then
  echo "error: already installed at $opt_dir -- run ./uninstall.sh first" >&2
  exit 1
fi

mkdir -p "$prefix/opt" "$prefix/bin" "$icon_dir" "$applications"
rm -rf "$opt_dir"
cp -a "$here" "$opt_dir"

ln -sfn "$opt_dir/pappus" "$bin_link"
cp "$here/$app_id.png" "$icon_dir/$app_id.png"
# The one edited line; everything else in the entry travels as it was packed.
sed "s|^Exec=.*|Exec=$opt_dir/pappus %U|" "$desktop" >"$applications/$app_id.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$applications" >/dev/null 2>&1 || true
fi

echo "Installed $app_id"
echo "  program       $opt_dir"
echo "  command       $bin_link"
echo "  menu entry    $applications/$app_id.desktop"
echo "  icon          $icon_dir/$app_id.png"
echo
echo "It may take a logout before the menu shows it. To put it on the desktop,"
echo "copy the menu entry to ~/Desktop and allow it to launch (GNOME: right-click"
echo "-> Allow Launching; KDE: make it executable)."
echo "To remove it again: $opt_dir/uninstall.sh"
