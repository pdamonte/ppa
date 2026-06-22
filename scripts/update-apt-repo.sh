#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="${ROOT_DIR}/docs"
SUITE="${1:-stable}"
COMPONENT="main"
ARCHES=("amd64" "arm64" "all")
PACKAGE_DIR="${DOCS_DIR}/pool/main/g/gc-cameras-dkms"
DEB_PATH="$("${ROOT_DIR}/scripts/build-deb.sh" "${ROOT_DIR}/build/deb")"
DEB_NAME="$(basename "${DEB_PATH}")"
REPO_DEB="${PACKAGE_DIR}/${DEB_NAME}"

mkdir -p "${PACKAGE_DIR}"
cp "${DEB_PATH}" "${REPO_DEB}"

make_packages_file() {
	local arch="$1"
	local binary_dir="${DOCS_DIR}/dists/${SUITE}/${COMPONENT}/binary-${arch}"
	local packages="${binary_dir}/Packages"
	local rel_deb="pool/main/g/gc-cameras-dkms/${DEB_NAME}"
	local size md5 sha1 sha256

	mkdir -p "${binary_dir}"
	size="$(stat -c '%s' "${REPO_DEB}")"
	md5="$(md5sum "${REPO_DEB}" | awk '{print $1}')"
	sha1="$(sha1sum "${REPO_DEB}" | awk '{print $1}')"
	sha256="$(sha256sum "${REPO_DEB}" | awk '{print $1}')"

	tmp_control="$(mktemp)"
	ar p "${REPO_DEB}" control.tar.xz > "${tmp_control}.tar.xz"
	tar -xOf "${tmp_control}.tar.xz" ./control > "${tmp_control}"
	cat "${tmp_control}" > "${packages}"
	{
		printf 'Filename: %s\n' "${rel_deb}"
		printf 'Size: %s\n' "${size}"
		printf 'MD5sum: %s\n' "${md5}"
		printf 'SHA1: %s\n' "${sha1}"
		printf 'SHA256: %s\n\n' "${sha256}"
	} >> "${packages}"
	rm -f "${tmp_control}" "${tmp_control}.tar.xz"
	gzip -9cn "${packages}" > "${packages}.gz"
}

for arch in "${ARCHES[@]}"; do
	make_packages_file "${arch}"
done

release="${DOCS_DIR}/dists/${SUITE}/Release"
mkdir -p "$(dirname "${release}")"
{
	printf 'Origin: pdamonte\n'
	printf 'Label: pdamonte-ppa\n'
	printf 'Suite: %s\n' "${SUITE}"
	printf 'Codename: %s\n' "${SUITE}"
	printf 'Date: %s\n' "$(LC_ALL=C date -Ru)"
	printf 'Architectures: %s\n' "${ARCHES[*]}"
	printf 'Components: %s\n' "${COMPONENT}"
	printf 'Description: GC camera DKMS packages for Ubuntu\n'
	printf 'MD5Sum:\n'
	find "${DOCS_DIR}/dists/${SUITE}" -type f \( -name Packages -o -name Packages.gz \) | sort | while read -r file; do
		rel="${file#"${DOCS_DIR}/dists/${SUITE}/"}"
		printf ' %s %16s %s\n' "$(md5sum "${file}" | awk '{print $1}')" "$(stat -c '%s' "${file}")" "${rel}"
	done
	printf 'SHA256:\n'
	find "${DOCS_DIR}/dists/${SUITE}" -type f \( -name Packages -o -name Packages.gz \) | sort | while read -r file; do
		rel="${file#"${DOCS_DIR}/dists/${SUITE}/"}"
		printf ' %s %16s %s\n' "$(sha256sum "${file}" | awk '{print $1}')" "$(stat -c '%s' "${file}")" "${rel}"
	done
} > "${release}"

rm -f "${release}.gpg" "${DOCS_DIR}/dists/${SUITE}/InRelease"
if [ -n "${APT_REPO_GPG_KEY:-}" ]; then
	gpg --batch --yes --local-user "${APT_REPO_GPG_KEY}" --clearsign --output "${DOCS_DIR}/dists/${SUITE}/InRelease" "${release}"
	gpg --batch --yes --local-user "${APT_REPO_GPG_KEY}" --detach-sign --armor --output "${release}.gpg" "${release}"
	gpg --batch --yes --local-user "${APT_REPO_GPG_KEY}" --export --output "${DOCS_DIR}/KEY.gpg"
fi

cat > "${DOCS_DIR}/index.html" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>pdamonte APT repository</title>
</head>
<body>
  <h1>pdamonte APT repository</h1>
  <p>Ubuntu DKMS package for GC5035 and GC8034 Intel IPU6 cameras.</p>
  <pre>deb [trusted=yes] https://pdamonte.github.io/ppa ${SUITE} ${COMPONENT}</pre>
</body>
</html>
EOF

find "${DOCS_DIR}" -type f | sort
