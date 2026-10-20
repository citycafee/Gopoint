$ErrorActionPreference = 'Stop'
Set-Location D:\milgo1\Downloads\Gopoint.app
$tmp = 'D:\OpenCodeTemp\opencode'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$md5 = [System.Security.Cryptography.MD5]::Create()
function Get-Hash([string]$f) { $h = $md5.ComputeHash([System.IO.File]::ReadAllBytes($f)); return (($h | ForEach-Object { $_.ToString('x2') }) -join '') }

foreach ($n in @('icon-192.png', 'icon-512.png', 'icon-512-maskable.png', 'favicon.ico', 'apple-touch-icon.png', 'sw.js')) {
  $live = Join-Path $tmp ('live-' + $n)
  try {
    Invoke-WebRequest -Uri "https://gopoint.vercel.app/$n" -OutFile $live -UseBasicParsing
    $same = if ((Get-Hash $live) -eq (Get-Hash $n)) { 'IDENTICAL to local' } else { 'DIFFERS from local' }
    Write-Host ("{0,-22} live={1} bytes  {2}" -f $n, (Get-Item $live).Length, $same)
  } catch { Write-Host "$n -> ERROR $($_.Exception.Message)" }
}
