#!/usr/bin/env bash
# Replaces third_party/sqlite3 with the current release from sqlite.org.
#
# The version is whatever sqlite.org's download page lists as current, since
# that page is also where the archive's hash is published; pass a version
# (`tool/update_sqlite.sh 3.53.5`) to refuse anything else. The archive is
# checked against that SHA3-256 before a byte of it is unpacked, only
# sqlite3.c and sqlite3.h are kept, and the provenance block in
# third_party/sqlite3/README.md is rewritten to match. Nothing is patched.
#
# Run the tests afterwards: the schema-migration tests exercise SQLite hardest.
set -euo pipefail

cd "$(dirname "$0")/.."
dest=third_party/sqlite3
want=${1:-}

page=$(curl -fsSL https://sqlite.org/download.html)
# The page carries a machine-readable line per product:
#   PRODUCT,<version>,<path>,<size>,<sha3-256>
line=$(grep -oE 'PRODUCT,[0-9.]+,[0-9]+/sqlite-amalgamation-[0-9]+\.zip,[0-9]+,[0-9a-f]{64}' <<<"$page" | head -n1)
[ -n "$line" ] || { echo "No amalgamation found on sqlite.org/download.html" >&2; exit 1; }
IFS=, read -r _ version path _ sha3 <<<"$line"

if [ -n "$want" ] && [ "$want" != "$version" ]; then
  echo "sqlite.org offers $version, not $want" >&2
  exit 1
fi
current=$(sed -nE 's/^#define SQLITE_VERSION +"([0-9.]+)".*/\1/p' "$dest/sqlite3.h")
if [ "$current" = "$version" ]; then
  echo "Already at SQLite $version."
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
url="https://sqlite.org/$path"
curl -fsSL -o "$tmp/amalgamation.zip" "$url"

got=$(python3 -c 'import hashlib,sys; print(hashlib.sha3_256(open(sys.argv[1],"rb").read()).hexdigest())' "$tmp/amalgamation.zip")
if [ "$got" != "$sha3" ]; then
  echo "SHA3-256 mismatch for $url" >&2
  echo "  expected $sha3" >&2
  echo "  got      $got" >&2
  exit 1
fi

unzip -q -j "$tmp/amalgamation.zip" '*/sqlite3.c' '*/sqlite3.h' -d "$tmp"
cp "$tmp/sqlite3.c" "$tmp/sqlite3.h" "$dest/"

sha_c=$(sha256sum "$dest/sqlite3.c" | cut -d' ' -f1)
sha_h=$(sha256sum "$dest/sqlite3.h" | cut -d' ' -f1)
block=$(cat <<EOF
<!-- provenance:start -->
SQLite **$version**, from:

    $url
    SHA3-256  $sha3   (as published on sqlite.org/download.html)
    sha256    $sha_c   sqlite3.c
    sha256    $sha_h   sqlite3.h
<!-- provenance:end -->
EOF
)
python3 - "$dest/README.md" "$block" <<'PY'
import re, sys
path, block = sys.argv[1], sys.argv[2]
text = open(path).read()
new, n = re.subn(r'<!-- provenance:start -->.*?<!-- provenance:end -->', block, text, flags=re.S)
if n != 1:
    sys.exit(f'{path}: expected one provenance block, found {n}')
open(path, 'w').write(new)
PY

echo "SQLite $current -> $version. Run flutter test before committing."
