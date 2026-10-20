$ErrorActionPreference = 'Stop'
$tmp = 'D:\OpenCodeTemp\opencode'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Add-Type -AssemblyName PresentationCore, WindowsBase

foreach ($n in @('icon-192.png', 'icon-512.png', 'icon-192-maskable.png', 'icon-512-maskable.png', 'favicon.ico', 'manifest.json', '/')) {
  $url = "https://gopoint.vercel.app/$n"
  $out = Join-Path $tmp ('live-' + ($n -replace '/', 'root'))
  try {
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
    if ($n -eq '/' -or $n -like '*.json') {
      $txt = Get-Content $out -Raw
      Write-Host "$n -> bytes=$($txt.Length) hasFaviconLink=$($txt -match 'favicon\.ico') hasMaskable=$($txt -match 'maskable')"
      continue
    }
    $uri = New-Object System.Uri($out)
    $bi = New-Object System.Windows.Media.Imaging.BitmapImage
    $bi.BeginInit(); $bi.CacheOption = 'OnLoad'; $bi.UriSource = $uri; $bi.EndInit()
    if ($bi.Format.ToString() -ne 'Bgra32') { $bi = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap($bi, [System.Windows.Media.PixelFormats]::Bgra32, $null, 0) }
    $stride = $bi.PixelWidth * 4
    $px = New-Object byte[] ($stride * $bi.PixelHeight)
    $bi.CopyPixels($px, $stride, 0)
    $a0 = 0; $a255 = 0
    for ($i = 3; $i -lt $px.Length; $i += 4) { $a = $px[$i]; if ($a -eq 0) { $a0++ } elseif ($a -eq 255) { $a255++ } }
    Write-Host ("{0} -> {1}x{2} alpha0={3} alpha255={4}" -f $n, $bi.PixelWidth, $bi.PixelHeight, $a0, $a255)
  } catch { Write-Host "$n -> ERROR $($_.Exception.Message)" }
}
