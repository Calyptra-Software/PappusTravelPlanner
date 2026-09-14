#!/usr/bin/env bash
# Package a built Linux bundle as a .tar.gz and an AppImage.
#
#   flutter build linux --release
#   tool/package_linux.sh <version> <output-dir>
#
# With PAPPUS_SIDE_BY_SIDE=true in the environment -- set for the *build* too,
# since that is what changes the application id (linux/CMakeLists.txt) -- the
# desktop entry, the icon and the file names are the CI build's, matching the
# bundle it packages.
#
# The same script for CI, a release and a local run, so a package that works
# on a laptop is the package the workflow publishes.
#
# Writes <output-dir>/pappus[-ci]-<version>-linux-x86_64.{tar.gz,AppImage}.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <version> <output-dir>" >&2
  exit 2
fi
version="$1"
out="$(mkdir -p "$2" && cd "$2" && pwd)"

root="$(cd "$(dirname "$0")/.." && pwd)"
bundle="$root/build/linux/x64/release/bundle"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [ ! -x "$bundle/pappus" ]; then
  echo "error: no release bundle at $bundle -- run 'flutter build linux --release' first" >&2
  exit 1
fi

if [ "${PAPPUS_SIDE_BY_SIDE:-}" = "true" ]; then
  app_id="dev.calyptra.pappus.ci"
  app_name="Pappus CI"
  icon_src="$root/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_ci.png"
  stem="pappus-ci-$version-linux-x86_64"
else
  app_id="dev.calyptra.pappus"
  app_name="Pappus Travel Planner"
  icon_src="$root/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
  stem="pappus-$version-linux-x86_64"
fi

# --- The oldest glibc this bundle runs on -----------------------------------
#
# What decides it is the highest symbol version the binaries *reference*, not
# the glibc of the machine that built them: a build on Ubuntu 24.04 (glibc 2.39)
# measured GLIBC_2.34, so it starts on Ubuntu 22.04 and Debian 12. A new plugin
# or a changed toolchain can raise that without anything else noticing, and the
# first to find out would be somebody whose app no longer starts. So the floor
# is asserted here. Raising it is a decision, made by editing this line.
max_glibc="2.35"
highest="$(
  find "$bundle" -type f \( -name pappus -o -name '*.so*' \) -print0 |
    xargs -0 objdump -T 2>/dev/null |
    grep -oE 'GLIBC_[0-9]+(\.[0-9]+)+' | sed 's/^GLIBC_//' | sort -Vu | tail -1
)"
echo "Highest glibc symbol version referenced: ${highest:-none}"
if [ -n "$highest" ] &&
  [ "$(printf '%s\n%s\n' "$highest" "$max_glibc" | sort -V | tail -1)" != "$max_glibc" ]; then
  echo "error: the bundle needs glibc $highest, above the supported floor of $max_glibc" >&2
  exit 1
fi

# --- What both packages carry beside the bundle -----------------------------
#
# StartupWMClass is the application id because the runner sets the program
# name to it (g_set_prgname in my_application.cc); that is how a desktop
# matches the open window to this entry and shows the right icon.
desktop_entry() {
  cat <<EOF
[Desktop Entry]
Type=Application
Name=$app_name
GenericName=Travel planner
Comment=Plan trips day by day, with transport, costs and checklists
Exec=$1
Icon=$app_id
Terminal=false
Categories=Utility;
StartupWMClass=$app_id
EOF
}

# --- .tar.gz ----------------------------------------------------------------
#
# The bundle as flutter built it, plus a desktop entry and an icon for whoever
# wants to put it in a menu. Sorted, with fixed owners and timestamps, and
# `gzip -n`, so that packing the same bundle twice gives the same file.
tar_dir="$work/$stem"
cp -a "$bundle" "$tar_dir"
desktop_entry pappus >"$tar_dir/$app_id.desktop"
cp "$icon_src" "$tar_dir/$app_id.png"
epoch="${SOURCE_DATE_EPOCH:-$(git -C "$root" log -1 --format=%ct)}"
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
  -C "$work" -cf - "$stem" | gzip -n -9 >"$out/$stem.tar.gz"
echo "Wrote $out/$stem.tar.gz"

# --- AppImage ---------------------------------------------------------------
#
# Both tools are pinned by version *and* digest: appimagetool would otherwise
# download the runtime from a rolling "continuous" release at build time, and
# the runtime is the part embedded in every AppImage handed out. The type2
# runtime is statically linked, so the result needs no libfuse2 on the user's
# machine -- the usual reason an AppImage fails to start on a recent Ubuntu.
appimagetool_url="https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage"
appimagetool_sha256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"
runtime_url="https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64"
runtime_sha256="2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d"

fetch() {
  curl -fsSL --retry 3 -o "$2" "$1"
  echo "$3  $2" | sha256sum -c --quiet -
}
fetch "$appimagetool_url" "$work/appimagetool" "$appimagetool_sha256"
fetch "$runtime_url" "$work/runtime" "$runtime_sha256"
chmod +x "$work/appimagetool"

# The bundle stays one directory, as flutter laid it out: the executable finds
# data/ and lib/ beside itself ($ORIGIN/lib), so AppRun only has to start it.
appdir="$work/AppDir"
cp -a "$bundle" "$appdir"
cat >"$appdir/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/pappus" "$@"
EOF
chmod +x "$appdir/AppRun"
desktop_entry pappus >"$appdir/$app_id.desktop"
cp "$icon_src" "$appdir/$app_id.png"
ln -s "$app_id.png" "$appdir/.DirIcon"

# APPIMAGE_EXTRACT_AND_RUN: the tool is itself an AppImage, and a CI runner has
# no FUSE to mount it with. SOURCE_DATE_EPOCH reaches mksquashfs through it.
APPIMAGE_EXTRACT_AND_RUN=1 SOURCE_DATE_EPOCH="$epoch" ARCH=x86_64 \
  "$work/appimagetool" --no-appstream --runtime-file "$work/runtime" \
  "$appdir" "$out/$stem.AppImage"
echo "Wrote $out/$stem.AppImage"
