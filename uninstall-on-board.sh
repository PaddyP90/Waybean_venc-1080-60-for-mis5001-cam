#!/bin/sh
# Restores the stock Luckfox setup from /root/waybeam-backup.  Runs ON THE BOARD.
set -u
ROOT=${ROOT:-}
SKIP_CHECKS=${SKIP_CHECKS:-0}
BK=$ROOT/root/waybeam-backup
IQNAME=mis5001_CMK-OT2115-PC1_30IRC-F16.json

[ -d "$BK" ] || { echo "ERROR: no backup folder $BK - nothing to restore" >&2; exit 1; }
[ "$SKIP_CHECKS" = 1 ] || { killall waybeam 2>/dev/null; }

rm -f "$ROOT/etc/init.d/S99waybeam"
[ -f "$BK/S99waybeam.orig" ] && cp -p "$BK/S99waybeam.orig" "$ROOT/etc/init.d/S99waybeam"
[ -f "$BK/mis5001.ko.orig" ] && cp -p "$BK/mis5001.ko.orig" "$ROOT/oem/usr/ko/mis5001.ko" && echo "> restored stock sensor driver"
[ -f "$BK/$IQNAME.orig" ] && cp -p "$BK/$IQNAME.orig" "$ROOT/etc/iqfiles/$IQNAME" && echo "> restored stock tuning file"
if [ -f "$BK/waybeam.json.orig" ]; then cp -p "$BK/waybeam.json.orig" "$ROOT/etc/waybeam.json"; else rm -f "$ROOT/etc/waybeam.json"; fi
if [ -f "$BK/waybeam.orig" ]; then cp -p "$BK/waybeam.orig" "$ROOT/usr/bin/waybeam"; else rm -f "$ROOT/usr/bin/waybeam"; fi
sync
echo "> Done. Power-cycle the board; the stock camera app (rkipc) starts again."
