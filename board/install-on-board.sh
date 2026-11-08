#!/bin/sh
# Installs waybeam (1080p ~60 fps) on a Luckfox Pico Ultra (RV1106) + MIS5001
# camera.  Runs ON THE BOARD.  Normally started by install.ps1 / install.sh.
#
#   sh install-on-board.sh --dest <receiver-ip> [--port 5600] [--hts 2700]
#                          [--bitrate 10000] [--no-driver]
#
# Safe to run more than once: the first run's backups are never overwritten.

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=${ROOT:-}                       # test hook: install into a fake root
SKIP_CHECKS=${SKIP_CHECKS:-0}        # test hook: skip root/kernel checks

DEST=""; PORT=5600; HTS=2700; BITRATE=10000; DRIVER=1
IQNAME=mis5001_CMK-OT2115-PC1_30IRC-F16.json
WANT_KERNEL=5.10.160
BK=$ROOT/root/waybeam-backup

say()  { echo "> $*"; }
warn() { echo "WARN: $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
	case "$1" in
	--dest) DEST=$2; shift 2 ;;
	--port) PORT=$2; shift 2 ;;
	--hts) HTS=$2; shift 2 ;;
	--bitrate) BITRATE=$2; shift 2 ;;
	--no-driver) DRIVER=0; shift ;;
	*) die "unknown option: $1" ;;
	esac
done
[ -n "$DEST" ] || die "missing --dest <ip of the PC/receiver>"
case "$HTS$BITRATE$PORT" in *[!0-9]*) die "--hts, --bitrate and --port must be numbers" ;; esac
[ "$HTS" -ge 1984 ] && [ "$HTS" -le 4000 ] || die "--hts must be between 1984 and 4000 (default 2700)"

# ---- checks (nothing is modified until all of these pass) -----------------
if [ "$SKIP_CHECKS" != 1 ]; then
	[ "$(id -u)" = 0 ] || die "run as root"
	command -v killall >/dev/null || die "killall not found - is this a Luckfox Buildroot image?"
fi
for f in waybeam mis5001.ko "$IQNAME" S99waybeam.template; do
	[ -f "$HERE/$f" ] || die "package file missing: $f"
done
[ -f "$ROOT/etc/iqfiles/$IQNAME" ] || die "camera tuning file /etc/iqfiles/$IQNAME not found.
This package is for the Luckfox MIS5001 module (CMK-OT2115-PC1_30IRC-F16)."
[ -d "$ROOT/oem/usr/ko" ] || die "/oem/usr/ko not found - unsupported image"

KVER=$(uname -r)
vermagic() { grep -a -o 'vermagic=[ -~]*' "$1" 2>/dev/null | head -1; }
if [ "$DRIVER" = 1 ]; then
	if [ "$SKIP_CHECKS" != 1 ] && [ "$KVER" != "$WANT_KERNEL" ]; then
		warn "kernel is $KVER, the sensor driver is built for $WANT_KERNEL"
		DRIVER=0
	elif [ ! -f "$ROOT/oem/usr/ko/mis5001.ko" ]; then
		warn "/oem/usr/ko/mis5001.ko not found on this board"
		DRIVER=0
	else
		# compare against the stock module (or our saved original)
		REF=$ROOT/oem/usr/ko/mis5001.ko
		[ -f "$BK/mis5001.ko.orig" ] && REF=$BK/mis5001.ko.orig
		A=$(vermagic "$REF"); B=$(vermagic "$HERE/mis5001.ko")
		if [ -n "$A" ] && [ "$A" != "$B" ]; then
			warn "sensor driver does not match this kernel:"
			warn "  board : $A"
			warn "  ours  : $B"
			DRIVER=0
		fi
	fi
	[ "$DRIVER" = 1 ] || warn "installing WITHOUT the 1080p driver (stock 2592x1944 mode, ~30 fps)"
fi

# ---- backups (first run only) ---------------------------------------------
mkdir -p "$BK"
bk() { [ -f "$1" ] && cp -p "$1" "$BK/$2" && say "backed up $1"; return 0; }
if [ ! -f "$BK/.installed" ]; then
	# first run only: save what the board had (a missing file = none saved)
	bk "$ROOT/oem/usr/ko/mis5001.ko" mis5001.ko.orig
	bk "$ROOT/etc/iqfiles/$IQNAME" "$IQNAME.orig"
	bk "$ROOT/etc/waybeam.json" waybeam.json.orig
	bk "$ROOT/etc/init.d/S99waybeam" S99waybeam.orig
	bk "$ROOT/usr/bin/waybeam" waybeam.orig
	date > "$BK/.installed"
else
	say "already installed once - keeping the original backups in $BK"
fi

# ---- stop anything using the camera ---------------------------------------
if [ "$SKIP_CHECKS" != 1 ]; then
	killall waybeam 2>/dev/null
	killall rkipc 2>/dev/null
fi

# ---- install --------------------------------------------------------------
mkdir -p "$ROOT/usr/bin" "$ROOT/etc/init.d" "$ROOT/etc/iqfiles"
cp "$HERE/waybeam" "$ROOT/usr/bin/waybeam.new" && chmod +x "$ROOT/usr/bin/waybeam.new" \
	&& mv "$ROOT/usr/bin/waybeam.new" "$ROOT/usr/bin/waybeam" || die "cannot install /usr/bin/waybeam"
say "installed /usr/bin/waybeam"

cp "$HERE/$IQNAME" "$ROOT/etc/iqfiles/$IQNAME" || die "cannot install tuning file"
say "installed camera tuning file (lens shading for the cropped sizes)"

if [ "$DRIVER" = 1 ]; then
	cp "$HERE/mis5001.ko" "$ROOT/oem/usr/ko/mis5001.ko" || die "cannot install sensor driver"
	say "installed sensor driver with 1080p crop mode"
	SIZE=1920x1080
	FPS=$((178200000 / (HTS * 1116)))
else
	SIZE=2592x1944
	FPS=30
fi

cat > "$ROOT/etc/waybeam.json" <<EOCFG
{
  "system": { "verbose": false, "webPort": 80 },
  "image": { "mirror": false, "flip": false },
  "video0": {
    "rcMode": "cbr",
    "fps": $FPS,
    "size": "$SIZE",
    "bitrate": $BITRATE,
    "gopSize": 1.0
  },
  "outgoing": {
    "enabled": true,
    "server": "udp://$DEST:$PORT",
    "maxPayloadSize": 1400,
    "connectedUdp": true
  },
  "snapshot": { "enabled": true, "quality": 70 }
}
EOCFG
say "wrote /etc/waybeam.json: $SIZE @ $FPS fps, $BITRATE kbps -> udp://$DEST:$PORT"

sed "s/@HTS@/$HTS/" "$HERE/S99waybeam.template" > "$ROOT/etc/init.d/S99waybeam" \
	&& chmod +x "$ROOT/etc/init.d/S99waybeam" || die "cannot install boot script"
say "installed boot script /etc/init.d/S99waybeam"
sync

cat <<EONOTE

Done.  The sensor driver is loaded at boot, so FULLY POWER-CYCLE the board
(unplug power, wait 5 s, plug in) - a plain 'reboot' is not reliable here.

After ~1 minute:  web UI  http://<board-ip>/   video  udp://$DEST:$PORT
Backups of the originals: /root/waybeam-backup   Undo: uninstall-on-board.sh
EONOTE
