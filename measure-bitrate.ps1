# Measures the real video bitrate arriving on the UDP port for 5 seconds (close the viewer first).
param([int]$Port = 5600)
$u = New-Object System.Net.Sockets.UdpClient($Port)
$ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any,0)
$u.Client.ReceiveTimeout = 2000
$sw = [Diagnostics.Stopwatch]::StartNew(); $bytes = 0
while ($sw.Elapsed.TotalSeconds -lt 5) { try { $b = $u.Receive([ref]$ep); $bytes += $b.Length } catch {} }
$u.Close()
"{0:N0} kbit/s" -f ($bytes * 8 / 1000 / 5)
