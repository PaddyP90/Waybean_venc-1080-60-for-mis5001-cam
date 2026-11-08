# Low-latency viewer for the waybeam stream (needs ffmpeg:  winget install Gyan.FFmpeg)
param([int]$Port = 5600)
$sdp = "v=0","o=- 0 0 IN IP4 127.0.0.1","s=waybeam","c=IN IP4 0.0.0.0","t=0 0","m=video $Port RTP/AVP 97","a=rtpmap:97 H265/90000"
$path = Join-Path $env:TEMP "waybeam.sdp"
Set-Content -Encoding ascii -Path $path -Value $sdp
ffplay -protocol_whitelist file,udp,rtp -fflags nobuffer -flags low_delay -framedrop -sync ext -analyzeduration 2000000 -probesize 2000000 -i $path
