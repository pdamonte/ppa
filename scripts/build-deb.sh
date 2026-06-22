#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-${ROOT_DIR}/build/deb}"
PACKAGE="gc-cameras-dkms"
DKMS_NAME="gc-cameras"
DKMS_VERSION="0.1.1"
DEB_VERSION="${DKMS_VERSION}-1"
ARCH="all"

WORK_DIR="$(mktemp -d)"
PKG_ROOT="${WORK_DIR}/pkg"
CONTROL_DIR="${PKG_ROOT}/DEBIAN"
DKMS_DIR="${PKG_ROOT}/usr/src/${DKMS_NAME}-${DKMS_VERSION}"
DEB="${OUT_DIR}/${PACKAGE}_${DEB_VERSION}_${ARCH}.deb"

cleanup() {
	rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

mkdir -p "${CONTROL_DIR}" "${DKMS_DIR}" "${OUT_DIR}"

install -m 0644 "${ROOT_DIR}/Makefile" "${ROOT_DIR}/dkms.conf" "${DKMS_DIR}/"
cp -a "${ROOT_DIR}/src" "${DKMS_DIR}/"
cp -a "${ROOT_DIR}/tools" "${DKMS_DIR}/"

find "${DKMS_DIR}" -type d -exec chmod 0755 {} +
find "${DKMS_DIR}" -type f -exec chmod 0644 {} +
chmod 0755 "${DKMS_DIR}/tools/"*.sh "${DKMS_DIR}/tools/"*.py

mkdir -p "${PKG_ROOT}/etc/modules-load.d"
cat > "${PKG_ROOT}/etc/modules-load.d/gc-cameras.conf" <<'EOF'
gti5035
gc8034
intel_ipu6_isys
EOF

cat > "${CONTROL_DIR}/control" <<EOF
Package: ${PACKAGE}
Version: ${DEB_VERSION}
Section: kernel
Priority: optional
Architecture: ${ARCH}
Maintainer: pdamonte <pdamonte@users.noreply.github.com>
Depends: dkms, gcc, make, linux-headers-generic | linux-headers-amd64, v4l-utils, python3, python3-pil
Homepage: https://github.com/pdamonte/ppa
Description: DKMS drivers for GC5035 and GC8034 Intel IPU6 cameras
 DKMS source package for GalaxyCore GCTI5035 and GCTI8034 camera sensors
 on Intel IPU6 systems. It builds the gti5035, gc8034 and patched ipu_bridge
 kernel modules for the installed kernel.
EOF

install -m 0755 "${ROOT_DIR}/debian/postinst" "${CONTROL_DIR}/postinst"
install -m 0755 "${ROOT_DIR}/debian/prerm" "${CONTROL_DIR}/prerm"
install -m 0755 "${ROOT_DIR}/debian/postrm" "${CONTROL_DIR}/postrm"

(
	cd "${PKG_ROOT}"
	tar --owner=0 --group=0 --numeric-owner -cJf "${WORK_DIR}/control.tar.xz" -C DEBIAN .
	tar --owner=0 --group=0 --numeric-owner -cJf "${WORK_DIR}/data.tar.xz" --exclude=DEBIAN .
	printf '2.0\n' > "${WORK_DIR}/debian-binary"
)

(
	cd "${WORK_DIR}"
	ar rcs "${DEB}" debian-binary control.tar.xz data.tar.xz
)

printf '%s\n' "${DEB}"
