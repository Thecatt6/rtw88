# Fix for previous build issues

## Issues fixed

### 1. rtw88.conf parse errors
Previous `rtw88.conf` had blank lines and comments that caused `kmod` to complain:
```
kmod_config_parse: /etc/modprobe.d/rtw88.conf line 6: ignoring bad line starting with '
```
This was due to blank lines being mis-parsed when file had Windows line endings or BOM after copy to /etc/modprobe.d, or due to kmod being strict.

**Fix**: New `rtw88.conf` has:
- No blank lines
- No comments
- Only valid `options` and `blacklist` directives
- Unix line endings (LF), no BOM
- Clean file generated via `cat >` without stray quotes

Install with:
```bash
sudo cp rtw88.conf /etc/modprobe.d/
sudo chmod 644 /etc/modprobe.d/rtw88.conf
# Verify no parse errors:
sudo depmod -a
# Should produce no kmod_config_parse errors
```

If you still see parse errors, check file for CRLF:
```bash
cat -A /etc/modprobe.d/rtw88.conf | head
# Should show $ at end of lines, not ^M$
# Fix CRLF:
sudo dos2unix /etc/modprobe.d/rtw88.conf || sudo sed -i 's/\r$//' /etc/modprobe.d/rtw88.conf
```

### 2. Exec format error for rtw_core
Previous build had vermagic `6.18.33.2-microsoft-standard-WSL2+` (note trailing `+`). Official WSL2 kernel is `6.18.33.2-microsoft-standard-WSL2` without `+`. The `+` comes from `scripts/setlocalversion` detecting dirty git tree.

**Fix**: New build:
- Clean git tree (`git reset --hard`)
- Fixed `scripts/setlocalversion` to strip quotes from CONFIG_LOCALVERSION
- Built with `LOCALVERSION=` to avoid `+` suffix
- Vermagic now: `6.18.33.2-microsoft-standard-WSL2` (no `+`)
- Also built with `modversions` enabled to match official kernel's `CONFIG_MODVERSIONS=y`

Verify:
```bash
strings rtw_core.ko | grep vermagic
# Should be: vermagic=6.18.33.2-microsoft-standard-WSL2 SMP preempt mod_unload modversions
```

If you still get Exec format error, check:
```bash
uname -r
# Should be 6.18.33.2-microsoft-standard-WSL2
# If your kernel is different (e.g. 6.6.x), you need to rebuild for your exact version
modinfo ./rtw_core.ko | grep vermagic
# Compare with uname -r

# Check architecture:
file rtw_core.ko
# Should be ELF 64-bit LSB relocatable, x86-64

# Check for unresolved symbols (due to empty Module.symvers, we built with KBUILD_MODPOST_WARN=1):
dmesg | grep rtw
# If you see "Unknown symbol" or "no symbol version", you need to use --force or rebuild with full Module.symvers

# Force load if vermagic matches but modversions mismatch:
sudo modprobe --force-vermagic rtw_core
sudo modprobe --force-vermagic rtw_usb
sudo modprobe --force-vermagic rtw_8822bu

# Or use insmod --force:
sudo insmod --force rtw_core.ko
```

### 3. Full rebuild method (recommended for exact match)

The most reliable way is to rebuild on your exact WSL kernel:

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

### 4. VHDX usage

New VHDX (`rtw88-modules.vhdx`) contains:
- `6.18.33.2-microsoft-standard-WSL2/modules/` with new .ko (no `+`, modversions)
- `linux-headers/` with UAPI headers
- `perf/` dummy

To use:
```bash
# Copy to WSL modules location (requires custom kernel that loads VHDX, or manual mount)
sudo mkdir -p /usr/lib/wsl
sudo cp rtw88-modules.vhdx /usr/lib/wsl/modules.vhdx

# Or mount manually:
sudo mkdir -p /mnt/rtw88mod
sudo mount -o loop rtw88-modules.img /mnt/rtw88mod
sudo cp -r /mnt/rtw88mod/6.18.33.2-microsoft-standard-WSL2/modules/* /lib/modules/6.18.33.2-microsoft-standard-WSL2/
sudo depmod -a 6.18.33.2-microsoft-standard-WSL2
sudo umount /mnt/rtw88mod
```

## Current build info

- Kernel: linux-msft-wsl-6.18.33.2, release 6.18.33.2-microsoft-standard-WSL2
- Vermagic: 6.18.33.2-microsoft-standard-WSL2 SMP preempt mod_unload modversions
- GCC: 12.2.0 (kernel built with 13.2.0, but compatible)
- MODVERSIONS: enabled (to match official WSL kernel)
- Built with: KBUILD_MODPOST_WARN=1 due to empty Module.symvers (still has unresolved symbol warnings, use --force if needed)
- For perfect CRC match, need full kernel modules build to generate Module.symvers

