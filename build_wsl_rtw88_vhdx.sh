#!/bin/bash
set -euo pipefail

# Build rtw88 for WSL2 kernel 6.18.33.2 and create modules.vhdx
# Usage: ./build_wsl_rtw88_vhdx.sh [kernel_tag]
# Default tag: linux-msft-wsl-6.18.33.2

KERNEL_TAG=${1:-linux-msft-wsl-6.18.33.2}
RTW88_SRC=${RTW88_SRC:-$(pwd)}
WSL_KERNEL_DIR=${WSL_KERNEL_DIR:-$HOME/WSL2-Linux-Kernel}
OUTPUT_VHDX=${OUTPUT_VHDX:-$RTW88_SRC/modules.vhdx}

echo "=== WSL2 rtw88 VHDX Builder ==="
echo "Kernel tag: $KERNEL_TAG"
echo "RTW88 src: $RTW88_SRC"
echo "WSL kernel dir: $WSL_KERNEL_DIR"
echo "Output VHDX: $OUTPUT_VHDX"

# 1. Install deps (Ubuntu/Debian)
if command -v apt >/dev/null 2>&1; then
  echo "[1/7] Installing build dependencies..."
  sudo apt update
  sudo apt install -y build-essential flex bison dwarves libssl-dev libelf-dev cpio qemu-utils rsync bc git python3-pip
  pip3 install --user FATtools || true
fi

# 2. Clone WSL2 kernel if needed
if [ ! -d "$WSL_KERNEL_DIR" ]; then
  echo "[2/7] Cloning WSL2-Linux-Kernel $KERNEL_TAG..."
  git clone --branch $KERNEL_TAG --depth 1 https://github.com/microsoft/WSL2-Linux-Kernel.git "$WSL_KERNEL_DIR"
else
  echo "[2/7] WSL kernel dir exists, fetching tag $KERNEL_TAG..."
  cd "$WSL_KERNEL_DIR"
  git fetch --depth 1 origin tag $KERNEL_TAG || true
  git checkout $KERNEL_TAG || git checkout -B tmp-$KERNEL_TAG $KERNEL_TAG
  cd -
fi

cd "$WSL_KERNEL_DIR"

# 3. Configure kernel
echo "[3/7] Configuring kernel..."
cp Microsoft/config-wsl .config
# Optional: disable heavy options to speed up and reduce deps
# scripts/config --disable MODVERSIONS || true
# scripts/config --disable DEBUG_INFO_BTF || true
# scripts/config --disable DEBUG_INFO_BTF_MODULES || true

# 4. Build kernel and modules
echo "[4/7] Building kernel and modules (this takes a while)..."
make KCONFIG_CONFIG=Microsoft/config-wsl -j$(nproc)
make KCONFIG_CONFIG=Microsoft/config-wsl INSTALL_MOD_PATH="$PWD/modules" modules_install -j$(nproc)

# 5. Install headers
echo "[5/7] Installing UAPI headers..."
make headers_install INSTALL_HDR_PATH="$PWD/headers"

# 6. Build perf (optional, may fail without extra deps)
echo "[6/7] Building perf tooling..."
mkdir -p "$PWD/perf"
make -C tools/perf NO_JEVENTS=1 NO_JVMTI=1 NO_LIBTRACEEVENT=1 install DESTDIR="$PWD/perf" prefix=/ || echo "perf build failed, continuing with empty perf dir"

# 7. Build rtw88 and add to modules
echo "[7/7] Building rtw88 and adding to modules tree..."
cd "$RTW88_SRC"
KVER=$(make -s -C "$WSL_KERNEL_DIR" kernelrelease)
echo "Kernel release: $KVER"
make KVER=$KVER KSRC="$WSL_KERNEL_DIR" -j$(nproc)
# Install rtw88 into the modules staging dir
mkdir -p "$WSL_KERNEL_DIR/modules/lib/modules/$KVER/kernel/drivers/net/wireless/rtw88"
cp *.ko "$WSL_KERNEL_DIR/modules/lib/modules/$KVER/kernel/drivers/net/wireless/rtw88/"
# Regenerate modules.dep
depmod -b "$WSL_KERNEL_DIR/modules" $KVER || /bin/busybox depmod -b "$WSL_KERNEL_DIR/modules" $KVER || true

# Pack into VHDX using Microsoft's script if available, else use FATtools fallback
cd "$WSL_KERNEL_DIR"
if [ -f "Microsoft/scripts/gen_artifacts_vhdx.sh" ]; then
  echo "Using Microsoft gen_artifacts_vhdx.sh..."
  ./Microsoft/scripts/gen_artifacts_vhdx.sh "$PWD/modules" "$PWD/headers" "$PWD/perf" $KVER "$OUTPUT_VHDX"
elif [ -f "Microsoft/scripts/gen_modules_vhdx.sh" ]; then
  echo "Using gen_modules_vhdx.sh (modules only)..."
  ./Microsoft/scripts/gen_modules_vhdx.sh "$PWD/modules" $KVER "$OUTPUT_VHDX"
else
  echo "Using FATtools fallback..."
  # Create staging per WSL layout
  STAGING=$(mktemp -d)
  mkdir -p "$STAGING/$KVER/modules"
  cp -r "$PWD/modules/lib/modules/$KVER"/* "$STAGING/$KVER/modules/"
  rm -f "$STAGING/$KVER/modules/build" "$STAGING/$KVER/modules/source"
  mkdir -p "$STAGING/$KVER/linux-headers"
  cp -r "$PWD/headers/." "$STAGING/$KVER/linux-headers/"
  mkdir -p "$STAGING/$KVER/perf"
  cp -r "$PWD/perf/." "$STAGING/$KVER/perf/"
  STAGING_SIZE=$(du -bs "$STAGING" | awk '{print $1;}')
  IMAGE_SIZE=$((STAGING_SIZE + 256*1024*1024))
  IMAGE_BLOCKS=$((IMAGE_SIZE / 1024))
  INODE_COUNT=$(find "$STAGING" | wc -l)
  INODE_COUNT=$((INODE_COUNT + 4096))
  mke2fs -q -L '' -d "$STAGING" -N $INODE_COUNT -b 1024 -t ext4 /tmp/modules.img $IMAGE_BLOCKS
  # Convert to VHDX
  if command -v qemu-img >/dev/null 2>&1; then
    qemu-img convert -O vhdx /tmp/modules.img "$OUTPUT_VHDX"
  else
    python3 -m FATtools.scripts.imgclone /tmp/modules.img "$OUTPUT_VHDX" -f || cp /tmp/modules.img "$OUTPUT_VHDX"
  fi
  rm -rf "$STAGING" /tmp/modules.img
fi

echo "=== Done ==="
echo "VHDX created at: $OUTPUT_VHDX"
ls -lh "$OUTPUT_VHDX"
echo "To use in WSL:"
echo "  Copy VHDX to Windows: cp $OUTPUT_VHDX /mnt/c/Users/<You>/modules.vhdx"
echo "  And follow README_WSL.md"
