#!/bin/sh
# Linux / macOS launcher.
#   ./install.sh BOARD_IP RECEIVER_IP [--hts 2700] [--bitrate 10000] [--port 5600] [--no-driver]
#   ./install.sh BOARD_IP --uninstall
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
BOARD=${1:?"usage: ./install.sh BOARD_IP RECEIVER_IP [options]   |   ./install.sh BOARD_IP --uninstall"}
shift
if [ "${1:-}" = "--uninstall" ]; then
	CMD="sh uninstall-on-board.sh"
else
	DEST=${1:?"missing RECEIVER_IP (the PC that gets the video)"}
	shift
	CMD="sh install-on-board.sh --dest $DEST $*"
fi
REMOTE=/tmp/wbinst-$(date +%Y%m%d%H%M%S)
echo "Copying files to $BOARD (board password; default 'luckfox')..."
scp -r "$HERE/board" "root@$BOARD:$REMOTE"
echo "Running the installer on the board (password again)..."
ssh "root@$BOARD" "cd $REMOTE && sed -i 's/\r\$//' *.sh S99waybeam.template && $CMD"
