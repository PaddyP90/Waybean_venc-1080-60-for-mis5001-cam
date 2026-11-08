# Prints the resolution and frame rate of the incoming stream (close the viewer first).
param([int]$Port = 5600)
$sdp = "v=0","o=- 0 0 IN IP4 127.0.0.1","s=waybeam","c=IN IP4 0.0.0.0","t=0 0","m=video $Port RTP/AVP 97","a=rtpmap:97 H265/90000"
$path = Join-Path $env:TEMP "waybeam.sdp"
Set-Content -Encoding ascii -Path $path -Value $sdp
ffprobe -v error -protocol_whitelist file,udp,rtp -analyzeduration 10000000 -probesize 10000000 -select_streams v:0 -show_entries stream=codec_name,width,height,avg_frame_rate -of default=nw=1 $path
