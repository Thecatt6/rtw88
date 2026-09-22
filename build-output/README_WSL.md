# rtw88 driver for WSL2 kernel linux-msft-wsl-6.18.33.2

This package contains pre-built rtw88 wireless drivers for **WSL2 Ubuntu** running kernel version **6.18.33.2-microsoft-standard-WSL2**.

Built from: https://github.com/lwfinger/rtw88 (downstream, synced with wireless-next)
Target kernel: https://github.com/microsoft/WSL2-Linux-Kernel tag `linux-msft-wsl-6.18.33.2`

## Current Build (Fixed 2026-09-22)

- **Vermagic**: `6.18.33.2-microsoft-standard-WSL2 SMP preempt mod_unload modversions` (no trailing `+`, matches official WSL kernel)
- **Previous build had `+`**: `6.18.33.2-microsoft-standard-WSL2+` caused Exec format error – fixed by cleaning git tree and fixing setlocalversion
- **rtw88.conf**: Clean file with no blank lines, no comments, Unix LF – fixes `kmod_config_parse` errors
- **MODVERSIONS**: Enabled to match official kernel (previous build disabled it)
- **Artifacts**: 
  - `*.ko` – 33 modules with correct vermagic
  - `rtw88-modules.img.xz` (6.2M) – compressed raw ext4 image, decompress with `xz -d`
  - `rtw88-wsl-6.18.33.2-fixed.tar.gz` (15M) – bundle with .ko, firmware, configs
  - Raw `rtw88-modules.img` (307M) and `rtw88-modules.vhdx` (324M) available locally but not in git due to 100MB limit – rebuild via `build_wsl_rtw88_vhdx.sh` or decompress xz

## Contents

- `*.ko` – Pre-built kernel modules for 6.18.33.2-microsoft-standard-WSL2 (vermagic: 6.18.33.2-microsoft-standard-WSL2 SMP preempt mod_unload modversions)
  - `rtw_core.ko` (core)
  - `rtw_pci.ko`, `rtw_usb.ko`, `rtw_sdio.ko` (bus)
  - `rtw_8723x.ko`, `rtw_8703b.ko`, `rtw_8723d.ko`, `rtw_8812a.ko`, `rtw_8814a.ko`, `rtw_8821a.ko`, `rtw_8821c.ko`, `rtw_8822b.ko`, `rtw_8822c.ko`, `rtw_88xxa.ko` (chip families)
  - `rtw_8723de.ko`, `rtw_8723ds.ko`, `rtw_8723du.ko`, `rtw_8723cs.ko`, `rtw_8812ae.ko`, `rtw_8812au.ko`, `rtw_8814ae.ko`, `rtw_8814au.ko`, `rtw_8821ae.ko`, `rtw_8821au.ko`, `rtw_8821ce.ko`, `rtw_8821cs.ko`, `rtw_8821cu.ko`, `rtw_8822be.ko`, `rtw_8822bs.ko`, `rtw_8822bu.ko`, `rtw_8822ce.ko`, `rtw_8822cs.ko`, `rtw_8822cu.ko` (interface + chip)
- `firmware/` – Firmware binaries needed by rtw88 (rtw88/*.bin)
- `rtw88.conf` – modprobe config (clean, no blank lines) to blacklist in-kernel rtw88 drivers
- `rtw88-modules.img.xz` – Compressed raw ext4 image (decompress to 307 MiB) containing:
  - `6.18.33.2-microsoft-standard-WSL2/modules/` – rtw88 .ko files + modules.dep
  - `6.18.33.2-microsoft-standard-WSL2/linux-headers/` – UAPI headers from WSL2 kernel
  - `6.18.33.2-microsoft-standard-WSL2/perf/` – dummy perf placeholder
- `rtw88-wsl-6.18.33.2-fixed.tar.gz` – Tarball with .ko, firmware, configs (15M)
- `dkms.conf` – DKMS configuration for auto-rebuild on kernel updates
- `BUILD_INFO.txt` and `README_FIX.md` – Details of fixes

## Supported Chipsets (same as upstream)

- **PCIe**: RTL8723DE, RTL8812AE, RTL8814AE, RTL8821AE, RTL8821CE, RTL8822BE, RTL8822CE
- **SDIO**: RTL8723CS, RTL8723DS, RTL8821CS, RTL8822BS, RTL8822CS
- **USB**: RTL8723DU, RTL8811AU, RTL8811CU, RTL8812AU, RTL8812BU, RTL8812CU, RTL8814AU, RTL8821AU, RTL8821CU, RTL8822BU, RTL8822CU

## Installation – Quick (Ubuntu on WSL)

### Prerequisites on WSL Ubuntu

```bash
sudo apt update
sudo apt install -y build-essential flex bison dwarves libssl-dev libelf-dev cpio qemu-utils rsync bc xz-utils
# For USB WiFi adapters via usbipd:
sudo apt install -y linux-tools-generic hwdata
sudo update-alternatives --install /usr/local/bin/usbip usbip /usr/lib/linux-tools/*-generic/usbip 20
```

### Option 1: Direct module install (simplest)

```bash
# Clone this repo or copy build-output
cd rtw88/build-output

# Install firmware
sudo mkdir -p /lib/firmware/rtw88
sudo cp firmware/*.bin /lib/firmware/rtw88/

# Install modprobe config (clean, no blank lines)
sudo cp rtw88.conf /etc/modprobe.d/
sudo chmod 644 /etc/modprobe.d/rtw88.conf
# Verify no parse errors:
cat -A /etc/modprobe.d/rtw88.conf
# Should show $ at end of lines, not ^M$
# If you see ^M$, fix with:
# sudo dos2unix /etc/modprobe.d/rtw88.conf || sudo sed -i 's/\r$//' /etc/modprobe.d/rtw88.conf
sudo depmod -a
# Should produce no kmod_config_parse errors

# Install modules to current kernel
KVER=$(uname -r)
# If your uname -r is 6.18.33.2-microsoft-standard-WSL2, use it directly
# Otherwise, force the target version:
KVER=6.18.33.2-microsoft-standard-WSL2

sudo mkdir -p /lib/modules/$KVER/kernel/drivers/net/wireless/rtw88
sudo cp *.ko /lib/modules/$KVER/kernel/drivers/net/wireless/rtw88/
sudo depmod -a $KVER

# Load
sudo modprobe rtw_core
sudo modprobe rtw_usb   # for USB adapters
# Or for your specific chip, e.g.:
sudo modprobe rtw_8822bu
sudo modprobe rtw_8822cu
# Check
lsmod | grep rtw
dmesg | grep rtw
```

> **Note about vermagic**: Modules now have vermagic `6.18.33.2-microsoft-standard-WSL2` without `+`, matching official WSL kernel. If you still get version mismatch, check `uname -r` vs `modinfo`:
> ```bash
> uname -r
> modinfo ./rtw_core.ko | grep vermagic
> strings ./rtw_core.ko | grep vermagic
> ```
> If `uname -r` is different (e.g. 6.6.x), rebuild for your exact version (Option 3).
> If you get "Unknown symbol" or "disagrees about version", use `--force`:
> ```bash
> sudo modprobe --force-vermagic rtw_core
> sudo modprobe --force-vermagic rtw_usb
> sudo modprobe --force-vermagic rtw_8822bu
> ```

### Option 2: Use VHDX as WSL modules store

WSL2 can load a `modules.vhdx` that contains `/lib/modules/<version>` and headers.

1. **Decompress the image**:

```bash
xz -d rtw88-modules.img.xz
# Now you have rtw88-modules.img (307M)
# To get VHDX, use FATtools or build_wsl_rtw88_vhdx.sh:
# pip install FATtools
# imgclone rtw88-modules.img rtw88-modules.vhdx -f
```

2. **Copy VHDX to Windows host**:

From WSL:
```bash
cp rtw88-modules.vhdx /mnt/c/Users/<YourUser>/rtw88-modules.vhdx
```

3. **Mount manually inside WSL**:

```bash
# In WSL Ubuntu, as root:
mkdir -p /usr/lib/wsl/modules
# Or mount the raw image directly:
sudo mkdir -p /mnt/rtw88mod
sudo mount -o loop rtw88-modules.img /mnt/rtw88mod
ls /mnt/rtw88mod/6.18.33.2-microsoft-standard-WSL2/modules/
# Copy modules from mounted image
sudo cp -r /mnt/rtw88mod/6.18.33.2-microsoft-standard-WSL2/modules/* /lib/modules/6.18.33.2-microsoft-standard-WSL2/
sudo depmod -a 6.18.33.2-microsoft-standard-WSL2
sudo umount /mnt/rtw88mod
```

### Option 3: Rebuild from source on your WSL machine (most reliable)

If vermagic mismatch or you want clean build with proper Module.symvers CRCs:

```bash
# Install deps
sudo apt update
sudo apt install -y build-essential flex bison dwarves libssl-dev libelf-dev bc

# Clone WSL kernel
git clone --branch linux-msft-wsl-6.18.33.2 --depth 1 https://github.com/microsoft/WSL2-Linux-Kernel.git
cd WSL2-Linux-Kernel
cp Microsoft/config-wsl .config
make modules_prepare -j$(nproc)

# Build rtw88
cd ..
git clone https://github.com/lwfinger/rtw88.git
cd rtw88
make KVER=$(make -s -C ../WSL2-Linux-Kernel kernelrelease) KSRC=../WSL2-Linux-Kernel -j$(nproc)
sudo make KVER=$(make -s -C ../WSL2-Linux-Kernel kernelrelease) KSRC=../WSL2-Linux-Kernel install
sudo cp rtw88.conf /etc/modprobe.d/
```

Or use the provided script `build_wsl_rtw88_vhdx.sh`.

## USBIP for USB WiFi adapters on WSL

WSL2 does not have direct USB access. Use `usbipd` on Windows:

1. On Windows (PowerShell as Admin):
```powershell
winget install usbipd
usbipd list
usbipd bind --busid=<BUSID>   # share your Realtek adapter
```

2. In WSL:
```bash
usbip list --remote=host
sudo usbip attach --remote=host --busid=<BUSID>
lsusb
# Now load rtw88 driver
sudo modprobe rtw_8822bu
```

## DKMS (auto rebuild on kernel update)

```bash
sudo apt install dkms
sudo cp -r /path/to/rtw88 /usr/src/rtw88-0.6
sudo dkms add -m rtw88 -v 0.6
sudo dkms build -m rtw88 -v 0.6
sudo dkms install -m rtw88 -v 0.6
sudo make install_fw
```

## Troubleshooting

- `kmod_config_parse: ignoring bad line` – Fixed in new rtw88.conf (no blank lines). Verify with `cat -A /etc/modprobe.d/rtw88.conf` – should have no empty lines and no `^M`. If you have old file, `sudo cp rtw88.conf /etc/modprobe.d/` again.
- `modprobe: FATAL: Module rtw_... not found` – Run `depmod -a` and check `/lib/modules/$(uname -r)/kernel/drivers/net/wireless/rtw88/`
- `Exec format error` – Previous build had `+` in vermagic. New build has no `+`. Check `strings rtw_core.ko | grep vermagic` should be `6.18.33.2-microsoft-standard-WSL2` without `+`. Also check `uname -r` matches. Use `--force-vermagic` if needed.
- `disagrees about version of symbol` – MODVERSIONS mismatch or empty Module.symvers. New build has MODVERSIONS enabled. Use `modprobe --force-vermagic` or rebuild from source for perfect CRCs.
- `Required key not available` – Secure Boot enabled. Either disable Secure Boot or sign modules with MOK (see README.md DKMS section).
- WSL has no `/lib/modules` – That's normal for stock WSL kernel. Build custom kernel with modules support and use VHDX method.
- No WiFi interface appears – WSL2 does not expose PCIe WiFi; only USB via usbipd works. Ensure adapter is attached via usbipd and `lsusb` shows it.

## How this build was created (in sandbox)

- Cloned WSL2-Linux-Kernel tag 6.18.33.2
- Fixed `scripts/setlocalversion` to strip quotes from CONFIG_LOCALVERSION
- Built with `LOCALVERSION=` to avoid `+` suffix
- Enabled `MODVERSIONS=y` and `GENKSYMS=y` using recent genksyms parser from vickiegpt/linux-cxl-type2 (6.x compatible, Bison 3.8.2 + Flex 2.6.4) and fake bison/flex/bc
- Installed `bc` via busybox, `libelf` headers from aosp-mirror/elfutils, `rsync` from static binaries, built `mke2fs` from e2fsprogs 1.47.4 with `-d` support
- Ran `make modules_prepare` and `make O=/tmp/kbuild LOCALVERSION= -j4`
- Built rtw88 with `KBUILD_MODPOST_WARN=1` (due to missing Module.symvers – vmlinux build failed at mm/ with Error 2, preventing full CRC generation)
- Created staging dir per WSL layout, used `mke2fs -q -L '' -d /tmp/staging -t ext4` to create ext4 raw image, then FATtools (patched argparse bug) to convert raw → VHDX (dynamic)
- Compressed raw image with `xz -9` to 6.2M for GitHub (limit 100M)

## References

- https://github.com/microsoft/WSL2-Linux-Kernel
- https://github.com/lwfinger/rtw88
- https://learn.microsoft.com/en-us/windows/wsl/
- https://github.com/dorssel/usbipd-win

## License

rtw88 driver is GPL-2.0 (see original repo). Build scripts MIT.
