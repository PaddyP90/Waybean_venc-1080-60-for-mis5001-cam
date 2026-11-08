# Rebuilding from source

**waybeam binary** (host: Linux or WSL)
```sh
git clone --depth 1 https://github.com/LuckfoxTECH/luckfox-pico   # SDK: toolchain + Rockchip headers/libs
unzip waybeam_venc-master.zip && cd waybeam_venc-master            # v0.85.6
patch -p1 < ../source/waybeam-rv1106.patch
python3 tools/build_webui.py                                       # regenerates src/venc_webui.c
make build SOC_BUILD=rv1106 RV1106_SDK=../luckfox-pico             # -> out/rv1106/waybeam
```
The patch adds the RV1106 backend (`src/rv1106_runtime.c`, `src/rv1106_jpeg.c`), the Live tab, and
RV1106 hooks in the shared API code.

**mis5001.ko** (kernel 5.10.160, Luckfox `luckfox_rv1106_linux_defconfig`)
```sh
cd luckfox-pico/sysdrv/source/kernel
: > .scmversion                                  # so the module version is "5.10.160", not "5.10.160+"
make ARCH=arm CROSS_COMPILE=arm-rockchip830-linux-uclibcgnueabihf- luckfox_rv1106_linux_defconfig modules_prepare
# copy source/mis5001.c to a folder with a one-line Makefile:  obj-m += mis5001.o
make -C <kernel dir> ARCH=arm CROSS_COMPILE=arm-rockchip830-linux-uclibcgnueabihf- M=$PWD modules
strings -a mis5001.ko | grep vermagic            # must read: 5.10.160 mod_unload ARMv7 thumb2 p2v8
```
Avoid 64-bit division in kernel modules on this kernel (`__aeabi_uldivmod` is not exported).
