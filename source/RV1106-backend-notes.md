# RV1106 backend (Luckfox Pico Ultra + MIS5001)

Pipeline: MIS5001 (MIPI) -> RKAIQ ISP -> VI chn0 -> `RK_MPI_SYS_Bind` -> VENC
(H.265) -> RTP/UDP.  A second small ISP output (VI chn1) feeds a JPEG VENC
channel used by the web dashboard's **Live** tab.  The shared HTTP API and
dashboard run unchanged on top (`venc_api.c` has an `rv1106` field whitelist).

Files: `src/rv1106_runtime.c`, `src/rv1106_jpeg.c`, `src/backend_rv1106.c`,
`include/rv1106_runtime.h`.

## Build

```sh
git clone --depth 1 https://github.com/LuckfoxTECH/luckfox-pico ../luckfox-pico
make build SOC_BUILD=rv1106 RV1106_SDK=../luckfox-pico
# -> out/rv1106/waybeam (ARM uclibc; needs librockit.so + librkaiq.so on target)
```

## Run

```sh
scp out/rv1106/waybeam root@<board>:/usr/bin/
scp config/waybeam.default.rv1106.json root@<board>:/etc/waybeam.json   # edit outgoing.server
ssh root@<board> 'WAYBEAM_IQ_DIR=/etc/iqfiles waybeam'
```

Open `http://<board-ip>/` (port = `system.webPort`, default 80).  The **Live**
tab polls `/api/v1/snapshot.jpg` (640px wide JPEG, 2/5/10 fps) — it uses a
separate encoder channel, so it costs the video link nothing while closed.

Receiver check: `gst-launch-1.0 udpsrc port=5600 caps="application/x-rtp,encoding-name=H265,payload=97" ! rtph265depay ! h265parse ! avdec_h265 ! autovideosink`

## Settings

| Applied live | Needs restart (auto cold-restart from the UI) |
|---|---|
| video0.bitrate, video0.gopSize, outgoing.enabled/server/maxPayloadSize, system.verbose, snapshot.quality, force IDR | video0.size/fps/rcMode, image.mirror/flip, snapshot.enabled, system.webPort, discovery.* |

Anything else is shown greyed out (not implemented on this backend).

## Limits

- **FPS:** the stock `mis5001.c` kernel driver has ONE mode, 2592x1944 @ 25 fps.
  `video0.fps` > 25 does not make the sensor faster.  60 fps needs a new
  sensor mode (register table + hts/vts) in the kernel driver, plus an IQ json.
- No ISP/IQ tuning tab, audio, recording or stabilization (routes answer 501 / are hidden).
- Untested on hardware: compiled and linked against the Luckfox SDK only.
  If a main size smaller than 2592x1944 fails at VI_SetChnAttr, use the
  sensor size first and tell me the exact error.
