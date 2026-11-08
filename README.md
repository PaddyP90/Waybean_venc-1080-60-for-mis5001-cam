# waybeam on Luckfox Pico Ultra — 1080p ~60 fps, web UI, live view

Runs the [waybeam_venc](https://github.com/OpenIPC) H.265 encoder on a **Luckfox Pico Ultra
(RV1106) with the MIS5001 camera**, with a patched camera driver that adds a **1920x1080 crop mode
at about 59 fps**, a **web UI** (settings, live preview, bitrate control) and **auto-start at boot**.
The video is sent as RTP/H.265 over UDP, for a PC player or a radio link (wfb-ng).

> Tested on one board (Luckfox Buildroot image dated 260604, kernel 5.10.160, camera module
> `CMK-OT2115-PC1_30IRC-F16`). If your board differs, the installer checks and falls back safely
> (see *What the installer checks*).

## What you need
- Luckfox Pico Ultra with the MIS5001 camera, on the **stock Luckfox Buildroot image**, on your network.
- A PC on the same network. Windows 10/11 needs the "OpenSSH Client" feature (usually already on).
- The board's IP address (check your router) and your PC's IP address (`ipconfig`).
  The board's login is `root`, default password `luckfox`.

## Install (Windows)
1. Unzip this folder. If PowerShell complains about scripts, use `install.cmd` (it bypasses that).
2. Open PowerShell in the folder and run (use your own addresses):
   ```powershell
   .\install.cmd -Board 192.168.0.132 -Dest 192.168.0.216
   ```
   `-Dest` is the PC that should receive the video. You will be asked for the board's password twice.
3. When it says *Done*, **unplug the board's power, wait 5 seconds, plug it back in**. (A plain
   `reboot` is not reliable for this camera driver. A full power cycle is.)
4. After about a minute, open `http://<board-ip>/` — the **Live** tab should show a picture.

Options: `-Port 5600`, `-Hts 2700` (sensor line length, see *Tuning*), `-Bitrate 10000` (kbit/s),
`-NoDriver` (keep the stock camera mode: 2592x1944, about 30 fps).

## Install (Linux / macOS)
```sh
./install.sh 192.168.0.132 192.168.0.216            # board IP, receiver IP
./install.sh 192.168.0.132 192.168.0.216 --hts 2800 --bitrate 12000
```

## Watch the video on the PC
Install ffmpeg once (`winget install Gyan.FFmpeg`), reopen PowerShell, then:
```powershell
.\tools\play.ps1              # low-latency player (ffplay)
.\tools\stream-info.ps1      # resolution + frame rate actually received
.\tools\measure-bitrate.ps1  # real bitrate over 5 seconds
```
`tools\play-gstreamer.txt` has a lower-latency GStreamer command. Close one viewer before opening
another: only one program can listen on UDP port 5600.

The **Live** tab in the web UI is a JPEG preview (a few frames per second) for framing the shot,
not the real video. Use the players above for the real stream.

## Web UI
`http://<board-ip>/` → **Settings** changes bitrate, GOP, output address and so on. Bitrate, GOP,
output address/enable and snapshot quality apply **live**; size, fps and rate-control mode need
**Save & Restart**. Click **Save & Restart** to keep a change after reboot.

## Tuning the frame rate
The sensor frame rate is set by its line length (`HTS`), with `fps = 178.2 MHz / (HTS x 1116)`:

| HTS | fps |   | HTS | fps |
|---|---|---|---|---|
| 3000 | 53 |   | 2650 | 60 |
| 2800 | 57 |   | 2500 | 64 |
| **2700** | **59** (default) |   | 2400 | 66 |

Lower HTS = faster, until the picture breaks (stripes, noise, black). On the board:
```sh
echo 2650 > /sys/module/mis5001/parameters/crop_hts      # then restart waybeam:
/etc/init.d/S99waybeam restart
```
To make a value permanent, edit `HTS=` in `/etc/init.d/S99waybeam` and set `"fps"` in
`/etc/waybeam.json` to match. Re-running the installer with `-Hts N` does both.

## What the installer checks (and does)
Before changing anything it checks: root, kernel version, that the MIS5001 tuning file exists, and
that the included sensor driver matches your board's stock driver build. If the driver doesn't
match, it installs **without** it (stock 2592x1944 mode, about 30 fps). If the tuning file is
missing it stops and changes nothing. It then backs up the originals (once, to `/root/waybeam-backup`),
installs the binary, the sensor driver, the camera tuning file, `/etc/waybeam.json` and the boot
script, which waits for the stock camera app (`rkipc`), stops it, and starts waybeam.

## Uninstall (back to stock)
```powershell
.\install.cmd -Board 192.168.0.132 -Uninstall      # then power-cycle the board
```
Linux/macOS: `./install.sh 192.168.0.132 --uninstall`.

## Troubleshooting
| Symptom | Try |
|---|---|
| Not running after a plain `reboot` | Power-cycle fully (unplug, wait, plug in) |
| `ps \| grep waybeam` shows nothing | `tail -25 /tmp/waybeam.log` on the board |
| `can't load library 'librockit.so'` | The boot script finds it in `/oem/usr/lib`; check the library exists there |
| Live tab black, log says `can't find 1920x1080 in lscResName` | Camera tuning file not installed — re-run the installer |
| Stripes/noise/black at your HTS | Raise HTS (e.g. 2800) |
| No video on PC | Check `-Dest` is your PC's IP (or edit `outgoing.server` in the UI); allow the player through Windows Firewall; close other players |
| `no sensor found on CSI port 0` | Power-cycle; check `dmesg \| grep mis5001` |

## Limits
- 1080p is a **centre crop** of the sensor (narrower view than the full 2592x1944 frame).
- Features not implemented on this board: audio, recording, ISP/IQ tuning tab, stabilization.
- The stream is H.265 only.

## What's in the box
```
install.cmd / install.ps1 / install.sh   PC launchers
board/    waybeam (ARM binary), mis5001.ko (sensor driver), camera tuning file, board-side scripts
tools/    viewer and measurement helpers, SDP file
source/   mis5001.c (modified driver) + mis5001.stock.c (original), waybeam-rv1106.patch, BUILD.md
SHA256SUMS
```

## Licences
- waybeam_venc: MIT (OpenIPC); the RV1106 backend and web-UI changes are in `source/waybeam-rv1106.patch`.
- `mis5001.ko` / `mis5001.c`: **GPL-2.0** (modified Luckfox/Rockchip kernel driver; source included).
- The camera tuning file is derived from the Rockchip/Luckfox MIS5001 tuning file (lens-shading tables
  added for the crop sizes, auto-exposure frame-rate cap lifted).
