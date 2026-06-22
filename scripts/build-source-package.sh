#!/usr/bin/env bash
set -euo pipefail

SERIES="${1:-noble}"
VERSION="${2:-0.1.1~${SERIES}1}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${ROOT_DIR}/build/ppa"
WORK_DIR="${BUILD_ROOT}/gc-cameras-dkms-${VERSION}"

if ! command -v dpkg-buildpackage >/dev/null 2>&1; then
	echo "Missing dpkg-buildpackage. Install packaging tools first:" >&2
	echo "  sudo apt install devscripts debhelper build-essential dput gnupg" >&2
	exit 1
fi

rm -rf "${WORK_DIR}"
mkdir -p "${BUILD_ROOT}" "${WORK_DIR}"

tar -C "${ROOT_DIR}" \
	--exclude=.git \
	--exclude=build \
	--exclude='*.deb' \
	--exclude='*.changes' \
	--exclude='*.buildinfo' \
	--exclude='*.dsc' \
	-cf - . | tar -C "${WORK_DIR}" -xf -

sed -i "1s/.*/gc-cameras-dkms (${VERSION}) ${SERIES}; urgency=medium/" "${WORK_DIR}/debian/changelog"

(
	cd "${WORK_DIR}"
	dpkg-buildpackage -S -sa
)

echo "Source package output:"
find "${BUILD_ROOT}" -maxdepth 1 -type f \( -name '*.dsc' -o -name '*.changes' -o -name '*.tar.*' \) -print | sort
