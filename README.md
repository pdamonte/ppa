# PPA packaging

Ubuntu/Launchpad PPA source packaging for the GalaxyCore GC5035 / GCTI5035
and GC8034 / GCTI8034 camera drivers on Intel IPU6 systems.

This repo builds one source package, `gc-cameras-dkms`, which installs DKMS
sources for:

- `gti5035`
- `gc8034`
- patched `ipu_bridge`

The resulting binary package is `gc-cameras-dkms`.

## Build a source upload

Install the packaging tools on Ubuntu:

```sh
sudo apt update
sudo apt install devscripts debhelper build-essential dput gnupg
```

Build a source package for an Ubuntu series:

```sh
./scripts/build-source-package.sh noble
```

The script writes source upload files under `build/ppa/`.

## Upload to a Launchpad PPA

Create the PPA in Launchpad first, then upload the generated source changes
file:

```sh
dput ppa:pdamonte/ppa build/ppa/gc-cameras-dkms_0.1.1~noble1_source.changes
```

Use the Ubuntu series that matches the target PPA build, for example `noble`,
`jammy`, or another enabled Launchpad series.

## Install from the PPA

After Launchpad finishes building and publishing the package:

```sh
sudo add-apt-repository ppa:pdamonte/ppa
sudo apt update
sudo apt install gc-cameras-dkms
```

## Related repositories

- <https://github.com/pdamonte/gc5035-dkms> - standalone GC5035 / GCTI5035 DKMS package.
- <https://github.com/pdamonte/gc8034-dkms> - standalone GC8034 / GCTI8034 DKMS package.
- <https://github.com/pdamonte/ipu-bridge-gc-cameras-akmod> - Fedora akmods package for the patched IPU bridge.

## License

GPL-2.0-only.
