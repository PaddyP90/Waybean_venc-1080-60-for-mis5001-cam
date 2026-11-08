<#
 Installs waybeam (1080p ~60 fps + web UI) on a Luckfox Pico Ultra with the
 MIS5001 camera, from Windows 10/11 (needs the built-in OpenSSH client).

   .\install.cmd -Board 192.168.0.132 -Dest 192.168.0.216
   .\install.cmd -Board 192.168.0.132 -Uninstall

 -Board   IP address of the Luckfox board
 -Dest    IP address of the PC (or radio TX) that should receive the video
 -Port    UDP port for the video            (default 5600)
 -Hts     sensor line length; lower = faster (default 2700 = ~59 fps)
 -Bitrate video bitrate in kbit/s            (default 10000)
 -NoDriver  install without the 1080p sensor driver (stock 2592x1944 mode)
#>
param(
  [Parameter(Mandatory=$true)][string]$Board,
  [string]$Dest,
  [int]$Port = 5600,
  [int]$Hts = 2700,
  [int]$Bitrate = 10000,
  [switch]$NoDriver,
  [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
foreach ($t in 'ssh','scp') {
  if (-not (Get-Command $t -ErrorAction SilentlyContinue)) {
    throw "'$t' not found. Turn on the 'OpenSSH Client' optional feature in Windows Settings > Apps > Optional features."
  }
}
$remote = "/tmp/wbinst-" + (Get-Date -Format yyyyMMddHHmmss)
if ($Uninstall) {
  $cmd = "sh uninstall-on-board.sh"
} else {
  if (-not $Dest) { $Dest = Read-Host "IP address of the PC that will receive the video" }
  if ($Dest -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { throw "Dest must be an IPv4 address like 192.168.0.216" }
  $extra = ""
  if ($NoDriver) { $extra = " --no-driver" }
  $cmd = "sh install-on-board.sh --dest $Dest --port $Port --hts $Hts --bitrate $Bitrate$extra"
}
Write-Host "Copying files to $Board  (enter the board's password; default is 'luckfox')..."
scp -r "$here\board" "root@${Board}:$remote"
if ($LASTEXITCODE -ne 0) { throw "scp failed - is the board's IP address right and the board powered on?" }
Write-Host "Running the installer on the board (password again)..."
ssh "root@$Board" "cd $remote && sed -i 's/\r$//' *.sh S99waybeam.template && $cmd"
if ($LASTEXITCODE -ne 0) { throw "The installer reported an error - see the messages above." }
