#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUITE="${1:-stable}"
COMPONENT="${2:-main}"
ARCHES=("amd64" "arm64" "all")
DIST_DIR="${ROOT_DIR}/dists/${SUITE}"
POOL_DIR="${ROOT_DIR}/pool"

if ! find "${POOL_DIR}" -type f -name '*.deb' -print -quit >/dev/null 2>&1; then
	echo "No .deb packages found under ${POOL_DIR}" >&2
	exit 1
fi

package_arch() {
	local deb="$1"
	local tmp_control
	tmp_control="$(mktemp)"
	ar p "${deb}" control.tar.xz > "${tmp_control}.tar.xz"
	tar -xOf "${tmp_control}.tar.xz" ./control > "${tmp_control}"
	awk -F': ' '/^Architecture:/ {print $2}' "${tmp_control}"
	rm -f "${tmp_control}" "${tmp_control}.tar.xz"
}

write_package_stanza() {
	local deb="$1"
	local packages="$2"
	local rel_deb="${deb#"${ROOT_DIR}/"}"
	local tmp_control size md5 sha1 sha256

	tmp_control="$(mktemp)"
	ar p "${deb}" control.tar.xz > "${tmp_control}.tar.xz"
	tar -xOf "${tmp_control}.tar.xz" ./control > "${tmp_control}"
	size="$(stat -c '%s' "${deb}")"
	md5="$(md5sum "${deb}" | awk '{print $1}')"
	sha1="$(sha1sum "${deb}" | awk '{print $1}')"
	sha256="$(sha256sum "${deb}" | awk '{print $1}')"

	cat "${tmp_control}" >> "${packages}"
	{
		printf 'Filename: %s\n' "${rel_deb}"
		printf 'Size: %s\n' "${size}"
		printf 'MD5sum: %s\n' "${md5}"
		printf 'SHA1: %s\n' "${sha1}"
		printf 'SHA256: %s\n\n' "${sha256}"
	} >> "${packages}"

	rm -f "${tmp_control}" "${tmp_control}.tar.xz"
}

for arch in "${ARCHES[@]}"; do
	binary_dir="${DIST_DIR}/${COMPONENT}/binary-${arch}"
	packages="${binary_dir}/Packages"
	mkdir -p "${binary_dir}"
	: > "${packages}"

	while IFS= read -r deb; do
		deb_arch="$(package_arch "${deb}")"
		if [ "${deb_arch}" = "${arch}" ] || [ "${deb_arch}" = "all" ]; then
			write_package_stanza "${deb}" "${packages}"
		fi
	done < <(find "${POOL_DIR}" -type f -name '*.deb' | sort)

	gzip -9cn "${packages}" > "${packages}.gz"
done

release="${DIST_DIR}/Release"
{
	printf 'Origin: pdamonte\n'
	printf 'Label: pdamonte-ppa\n'
	printf 'Suite: %s\n' "${SUITE}"
	printf 'Codename: %s\n' "${SUITE}"
	printf 'Date: %s\n' "$(LC_ALL=C date -Ru)"
	printf 'Architectures: %s\n' "${ARCHES[*]}"
	printf 'Components: %s\n' "${COMPONENT}"
	printf 'Description: pdamonte Ubuntu APT repository\n'
	printf 'MD5Sum:\n'
	find "${DIST_DIR}" -type f \( -name Packages -o -name Packages.gz \) | sort | while read -r file; do
		rel="${file#"${DIST_DIR}/"}"
		printf ' %s %16s %s\n' "$(md5sum "${file}" | awk '{print $1}')" "$(stat -c '%s' "${file}")" "${rel}"
	done
	printf 'SHA256:\n'
	find "${DIST_DIR}" -type f \( -name Packages -o -name Packages.gz \) | sort | while read -r file; do
		rel="${file#"${DIST_DIR}/"}"
		printf ' %s %16s %s\n' "$(sha256sum "${file}" | awk '{print $1}')" "$(stat -c '%s' "${file}")" "${rel}"
	done
} > "${release}"

rm -f "${release}.gpg" "${DIST_DIR}/InRelease"
if [ -n "${APT_REPO_GPG_KEY:-}" ]; then
	gpg --batch --yes --local-user "${APT_REPO_GPG_KEY}" --clearsign --output "${DIST_DIR}/InRelease" "${release}"
	gpg --batch --yes --local-user "${APT_REPO_GPG_KEY}" --detach-sign --armor --output "${release}.gpg" "${release}"
	gpg --batch --yes --local-user "${APT_REPO_GPG_KEY}" --export --output "${ROOT_DIR}/KEY.gpg"
fi

cat > "${ROOT_DIR}/index.html" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>pdamonte APT repository</title>
</head>
<body>
  <h1>pdamonte APT repository</h1>
  <p>Ubuntu packages published by pdamonte.</p>
  <pre>deb [trusted=yes] https://pdamonte.github.io/ppa ${SUITE} ${COMPONENT}</pre>
</body>
</html>
EOF

find "${DIST_DIR}" "${POOL_DIR}" -type f | sort
