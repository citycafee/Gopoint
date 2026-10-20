$ErrorActionPreference = 'Stop'
Set-Location D:\milgo1\Downloads\Gopoint.app
foreach ($f in @('manifest.json', 'vercel.json')) {
  try { Get-Content $f -Raw | ConvertFrom-Json | Out-Null; Write-Host "JSON OK: $f" }
  catch { Write-Host "JSON BAD: $f -> $($_.Exception.Message)" }
}
Add-Type -AssemblyName System.Drawing
$ic = New-Object System.Drawing.Icon('favicon.ico')
Write-Host "favicon.ico loaded: $($ic.Width)x$($ic.Height)"
$ic.Dispose()
$im = [System.Drawing.Image]::FromFile((Resolve-Path 'favicon.ico'))
Write-Host "favicon.ico as image: $($im.Width)x$($im.Height)"
$im.Dispose()

# manifest sanity: every referenced icon exists
$m = Get-Content manifest.json -Raw | ConvertFrom-Json
foreach ($i in $m.icons) {
  $exists = Test-Path $i.src
  Write-Host "manifest icon: $($i.src) purpose=$($i.purpose) exists=$exists"
}
foreach ($src in (Get-Content vercel.json -Raw | ConvertFrom-Json).builds.src) {
  Write-Host "vercel build entry: $src exists=$(Test-Path $src)"
}
Remove-Item 'maskable-test.png' -ErrorAction SilentlyContinue
Write-Host 'cleaned maskable-test.png'
