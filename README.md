# libfprint-ft9201

Installs the FocalTech FT9201/FT9338 fingerprint reader on Fedora-based Linux systems (including Bazzite, rpm-ostree).

**Device:** USB `2808:9338` — FocalTech FT9201Fingerprint
**Tested on:** Bazzite 43 (Fedora 43, rpm-ostree), GPD Win 4 HX370

## How it works

The standard Fedora libfprint does not include a driver for this sensor. This installer:

1. Downloads the proprietary Focal-systems.Corp libfprint TOD binary (from Ubuntu 22.04)
2. Bundles a compatible `libgusb.so.2` (0.3.x — required because Fedora ships 0.4.x which removed `g_usb_device_get_interfaces`)
3. Patches the rpath so the TOD library finds the bundled libgusb
4. Installs a systemd service that bind-mounts the TOD library over the system libfprint at boot
5. On Bazzite/GPD Win 4: masks the udev rule that removes the device at boot

The binary is never stored in this repo (proprietary). It is downloaded at install time and verified via sha256.

## Requirements

- Fedora-based system (Fedora, Bazzite, RHEL, etc.)
- `x86_64` architecture
- `curl`, `patchelf`, `systemd`
- fprintd: `sudo dnf install fprintd fprintd-pam` (or `rpm-ostree install fprintd fprintd-pam`)

## Install

```bash
sudo dnf install patchelf fprintd fprintd-pam   # or rpm-ostree install ...
git clone https://github.com/ArcheoCodix/libfprint-ft9201
cd libfprint-ft9201
sudo ./install.sh
```

Then enroll a finger:

```bash
fprintd-enroll
fprintd-verify
```

## Bazzite / rpm-ostree notes

On Bazzite (immutable OS), `rpm-ostree override replace` does not work for image-provided packages. The bind mount approach used here works around this — the TOD library is stored in `/etc/libfprint-focaltech/` (persistent) and mounted over `/usr/lib64/libfprint-2.so.2.0.0` at boot via a systemd oneshot service.

The Bazzite GPD Win 4 image ships a udev rule (`50-gpd-win-4-fingerprint.rules`) that removes the fingerprint device at boot to avoid suspend issues. This installer masks that rule. If you experience suspend/wake problems afterwards, you can restore it:

```bash
sudo rm /etc/udev/rules.d/50-gpd-win-4-fingerprint.rules
sudo udevadm control --reload-rules
```

## Binary source

The proprietary binary comes from [ryenyuku/libfprint-ft9201](https://github.com/ryenyuku/libfprint-ft9201), which repackages the Focal-systems.Corp Ubuntu deb.

Original source: `libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_amd64_20250219.deb`
sha256: `fe8c5ebb685718075e1fc04f10378c001e149b80c283d2891318a50e0588401a`

The binary is proprietary (Focal-systems.Corp). Do not redistribute it directly.

## Related projects

- [ryenyuku/libfprint-ft9201](https://github.com/ryenyuku/libfprint-ft9201) — Arch/AUR packaging
- [banianitc/ft9201-fingerprint-driver](https://github.com/banianitc/ft9201-fingerprint-driver) — open source kernel module (no fprintd integration)
