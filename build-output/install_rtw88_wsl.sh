#!/bin/bash
set -euo pipefail

# Install rtw88 driver for WSL2 kernel 6.18.33.2-microsoft-standard-WSL2

KVER=${KVER:-6.18.33.2-microsoft-standard-WSL2}
# Allow override via uname -r if user wants current kernel
if [ "${USE_UNAME:-0}" = "1" ]; then
  KVER=$(uname -r)
fi

echo "Installing rtw88 for kernel $KVER..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Install firmware
echo "[1/4] Installing firmware..."
mkdir -p /lib/firmware/rtw88
cp -v "$SCRIPT_DIR/firmware/"*.bin /lib/firmware/rtw88/ || echo "No firmware files found, skipping"

# Install modprobe config
echo "[2/4] Installing modprobe config..."
cp -v "$SCRIPT_DIR/rtw88.conf" /etc/modprobe.d/

# Install modules
echo "[3/4] Installing kernel modules to /lib/modules/$KVER/..."
mkdir -p /lib/modules/$KVER/kernel/drivers/net/wireless/rtw88
cp -v "$SCRIPT_DIR"/*.ko /lib/modules/$KVER/kernel/drivers/net/wireless/rtw88/

# Depmod
echo "[4/4] Running depmod..."
depmod -a $KVER || busybox depmod -a $KVER || echo "depmod not found, you may need to run it manually"

echo "Done. You can now load modules:"
echo "  modprobe rtw_core"
echo "  modprobe rtw_usb"
echo "  modprobe rtw_8822bu   # example for RTL8822BU"
echo ""
echo "Check with: lsmod | grep rtw ; dmesg | grep rtw"
echo ""
echo "If you get vermagic mismatch, try:"
echo "  modprobe --force-vermagic rtw_8822bu"
