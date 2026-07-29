#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(PYTHONPATH="$ROOT_DIR" python3 -c 'from glow_kit import __version__; print(__version__)')"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
SOURCE_NAME="fedora-glow-kit-$VERSION"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$ROOT_DIR" log -1 --format=%ct)}"
export SOURCE_DATE_EPOCH

command -v rpmbuild >/dev/null 2>&1 || {
  printf 'rpmbuild is required. Install rpm-build first.\n' >&2
  exit 2
}

mkdir -p "$DIST_DIR"
(
  cd "$ROOT_DIR"
  git ls-files -z --cached --others --exclude-standard |
    LC_ALL=C sort -z |
    tar --null --files-from=- \
      --hard-dereference \
      --transform="s|^|$SOURCE_NAME/|" \
      --sort=name \
      --mtime="@$SOURCE_DATE_EPOCH" \
      --owner=0 --group=0 --numeric-owner \
      --format=posix \
      --pax-option=delete=atime,delete=ctime \
      -cf -
) | gzip -n >"$DIST_DIR/$SOURCE_NAME.tar.gz"

rpmbuild -ba "$ROOT_DIR/packaging/fedora-glow-kit.spec" \
  --define "_buildhost reproducible.fedoraproject.org" \
  --define "build_mtime_policy clamp_to_source_date_epoch" \
  --define "source_date_epoch_from_changelog 0" \
  --define "use_source_date_epoch_as_buildtime 1" \
  --define "_sourcedir $DIST_DIR" \
  --define "_srcrpmdir $DIST_DIR/srpm" \
  --define "_rpmdir $DIST_DIR/rpm"

python3 "$ROOT_DIR/scripts/generate-sbom.py" "$DIST_DIR/fedora-glow-kit-$VERSION.spdx.json"
(
  cd "$DIST_DIR"
  sha256sum "$SOURCE_NAME.tar.gz" rpm/noarch/*.rpm srpm/*.src.rpm \
    "fedora-glow-kit-$VERSION.spdx.json" >SHA256SUMS
)
printf 'Release artifacts written to %s\n' "$DIST_DIR"
