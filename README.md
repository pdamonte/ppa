# pdamonte APT repository

Static Ubuntu APT repository served from GitHub Pages.

Repository URL:

```text
https://pdamonte.github.io/ppa
```

Install on Ubuntu:

```sh
echo "deb [trusted=yes] https://pdamonte.github.io/ppa stable main" | sudo tee /etc/apt/sources.list.d/pdamonte-ppa.list
sudo apt update
sudo apt install gc-cameras-dkms
```

This repository intentionally contains only published package artifacts and APT
metadata. Package and driver sources live in separate source repositories.

## Standard APT Layout

```text
.
├── dists/
│   └── stable/
│       ├── Release
│       └── main/
│           ├── binary-all/
│           │   ├── Packages
│           │   └── Packages.gz
│           ├── binary-amd64/
│           │   ├── Packages
│           │   └── Packages.gz
│           └── binary-arm64/
│               ├── Packages
│               └── Packages.gz
├── pool/
│   └── main/
│       └── g/
│           └── gc-cameras-dkms/
│               └── gc-cameras-dkms_0.1.1-1_all.deb
├── index.html
└── scripts/
    └── update-apt-repo.sh
```

## Update Metadata

After adding or replacing `.deb` files under `pool/`, regenerate the repository
metadata:

```sh
./scripts/update-apt-repo.sh stable main
```

Then commit and push the updated `dists/`, `pool/` and `index.html` files.

If `APT_REPO_GPG_KEY` is set to a local GPG key id, the script also writes
`InRelease`, `Release.gpg` and `KEY.gpg`.

## Package Sources

- <https://github.com/pdamonte/gc-cameras-ubuntu-dkms> - combined Ubuntu DKMS package source for the published `gc-cameras-dkms` package.
- <https://github.com/pdamonte/gc5035-dkms> - GC5035 / GCTI5035 DKMS package source.
- <https://github.com/pdamonte/gc8034-dkms> - GC8034 / GCTI8034 DKMS package source.
- <https://github.com/pdamonte/ipu-bridge-gc-cameras-akmod> - Fedora akmods package source for the patched IPU bridge.

## Signing

This repository is currently unsigned, so the install example uses
`[trusted=yes]`. For production use, sign the repository metadata and use an
APT source with `signed-by=...` instead.
