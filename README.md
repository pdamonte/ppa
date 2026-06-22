# pdamonte APT repository

Static Ubuntu APT repository for GalaxyCore GC5035 / GCTI5035 and
GC8034 / GCTI8034 camera drivers on Intel IPU6 systems.

The published package is:

- `gc-cameras-dkms`: installs DKMS sources for `gti5035`, `gc8034` and the
  patched `ipu_bridge` module.

## Install

Once GitHub Pages is enabled for this repository:

```sh
sudo install -d -m 0755 /etc/apt/sources.list.d
echo "deb [trusted=yes] https://pdamonte.github.io/ppa stable main" | sudo tee /etc/apt/sources.list.d/pdamonte-ppa.list
sudo apt update
sudo apt install gc-cameras-dkms
```

`trusted=yes` is used because this repository is currently generated without a
GPG signing key. For production use, sign `Release` with a repository key and
install that key on the target system instead of using `trusted=yes`.

## Repository layout

The APT repository is generated under `docs/` so GitHub Pages can serve it:

```text
docs/
  dists/stable/main/binary-amd64/Packages
  dists/stable/main/binary-arm64/Packages
  dists/stable/main/binary-all/Packages
  pool/main/g/gc-cameras-dkms/gc-cameras-dkms_0.1.1-1_all.deb
```

## Update the APT repo

```sh
./scripts/update-apt-repo.sh stable
git add .
git commit -m "Update APT repository"
git push
```

If `APT_REPO_GPG_KEY` is set to a local GPG key id, the script also writes
`InRelease`, `Release.gpg` and `KEY.gpg`.

## Package source layout

```text
.
├── dkms.conf
├── Makefile
├── src/
├── tools/
└── debian/
    ├── control
    ├── rules
    ├── changelog
    ├── compat
    └── install
```

## Related repositories

- <https://github.com/pdamonte/gc5035-dkms> - standalone GC5035 / GCTI5035 DKMS package.
- <https://github.com/pdamonte/gc8034-dkms> - standalone GC8034 / GCTI8034 DKMS package.
- <https://github.com/pdamonte/ipu-bridge-gc-cameras-akmod> - Fedora akmods package for the patched IPU bridge.

## License

GPL-2.0-only.
