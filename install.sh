#!/bin/bash
# libfprint-ft9201 installer
# Installs the FocalTech FT9201/FT9338 fingerprint reader driver for Fedora/Bazzite
# and other RPM-based systems using the libfprint TOD (proprietary binary) approach.
#
# Tested on: Bazzite 43 (Fedora 43, ostree/rpm-ostree), GPD Win 4 HX370
# Device: USB 2808:9338 (FocalTech FT9201Fingerprint)
#
# Source binary: Focal-systems.Corp via ryenyuku/libfprint-ft9201
# License: proprietary (Focal-systems.Corp) — do not redistribute the binary

set -e

# --- Config ---
DEB_URL="https://github.com/ryenyuku/libfprint-ft9201/releases/download/1.94.4_20250219/libfprint-2-2_1.94.4+tod1-0ubuntu1.22.04.2_amd64_20250219.deb"
DEB_SHA256="fe8c5ebb685718075e1fc04f10378c001e149b80c283d2891318a50e0588401a"

GUSB_URL="https://github.com/ryenyuku/libfprint-ft9201/releases/download/1.94.4_20250219/libgusb.so.2"
GUSB_SHA256="04af98a8a9c2528966c93cea3c3fd5c1b67b002a65a2e875e70e025d28419da6"

INSTALL_DIR="/etc/libfprint-focaltech"
VENDOR_ID="2808"
PRODUCT_ID="9338"

# --- Checks ---
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo $0)"
    exit 1
fi

for cmd in curl ar patchelf systemctl udevadm; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Missing dependency: $cmd"
        echo "Install with: sudo dnf install $cmd"
        exit 1
    fi
done

# --- Download and verify ---
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

echo "==> Downloading libfprint TOD binary..."
curl -L -o "$WORK_DIR/libfprint.deb" "$DEB_URL"
echo "$DEB_SHA256  $WORK_DIR/libfprint.deb" | sha256sum -c - || {
    echo "ERROR: checksum mismatch for deb — file may have changed upstream"
    exit 1
}

echo "==> Downloading bundled libgusb (Ubuntu 22.04 / 0.3.x)..."
curl -L -o "$WORK_DIR/libgusb.so.2" "$GUSB_URL"
echo "$GUSB_SHA256  $WORK_DIR/libgusb.so.2" | sha256sum -c - || {
    echo "ERROR: checksum mismatch for libgusb.so.2"
    exit 1
}

# --- Extract deb ---
echo "==> Extracting deb..."
cd "$WORK_DIR"
ar x libfprint.deb
tar xf data.tar.*
LIBFPRINT_SO=$(find . -name "libfprint-2.so.2*" -not -type l | head -1)
[ -z "$LIBFPRINT_SO" ] && { echo "ERROR: libfprint-2.so.2 not found in deb"; exit 1; }

# --- Install library ---
echo "==> Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp "$LIBFPRINT_SO" "$INSTALL_DIR/libfprint-2.so.2.0.0"
cp libgusb.so.2 "$INSTALL_DIR/libgusb.so.2"
chmod 755 "$INSTALL_DIR/libfprint-2.so.2.0.0"

# Patch rpath so the TOD libfprint finds the bundled libgusb (0.3.x)
# instead of the system libgusb (0.4.x, which removed g_usb_device_get_interfaces)
echo "==> Patching rpath..."
patchelf --add-rpath "$INSTALL_DIR" "$INSTALL_DIR/libfprint-2.so.2.0.0"

# --- Install systemd bind mount service ---
echo "==> Installing systemd service..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/libfprint-focaltech-bind.service" /etc/systemd/system/libfprint-focaltech-bind.service

systemctl daemon-reload
systemctl enable libfprint-focaltech-bind.service

# --- udev rule: start fprintd when device appears ---
echo "==> Installing udev rule..."
cat > /etc/udev/rules.d/99-ft9201.rules << EOF
# FocalTech FT9201 Fingerprint Reader (USB ${VENDOR_ID}:${PRODUCT_ID})
# Trigger fprintd to start when the device appears
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="${VENDOR_ID}", ATTRS{idProduct}=="${PRODUCT_ID}", \
    RUN+="/usr/bin/systemctl --no-block start fprintd.service"
EOF

# --- Bazzite: mask the udev rule that removes the device ---
if [ -f /usr/lib/udev/rules.d/50-gpd-win-4-fingerprint.rules ]; then
    echo "==> Bazzite detected: masking GPD fingerprint removal rule..."
    ln -sf /dev/null /etc/udev/rules.d/50-gpd-win-4-fingerprint.rules
fi

udevadm control --reload-rules

# --- Start services ---
echo "==> Starting services..."
systemctl start libfprint-focaltech-bind.service
systemctl restart fprintd

echo ""
echo "==> Done! Test with:"
echo "    fprintd-list \$(whoami)"
echo "    fprintd-enroll   # to enroll a finger"
echo "    fprintd-verify   # to test recognition"
