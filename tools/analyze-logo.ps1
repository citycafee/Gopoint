$ErrorActionPreference = 'Stop'
Set-Location D:\milgo1\Downloads\Gopoint.app
Add-Type -AssemblyName PresentationCore, WindowsBase

$uri = New-Object System.Uri('E:\logo.png')
$bi = New-Object System.Windows.Media.Imaging.BitmapImage
$bi.BeginInit(); $bi.CacheOption = 'OnLoad'; $bi.UriSource = $uri; $bi.EndInit()
if ($bi.Format.ToString() -ne 'Bgra32') { $bi = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap($bi, [System.Windows.Media.PixelFormats]::Bgra32, $null, 0) }
$w = $bi.PixelWidth; $h = $bi.PixelHeight
$stride = $w * 4
$px = New-Object byte[] ($stride * $h)
$bi.CopyPixels($px, $stride, 0)
Write-Host "size: ${w}x$h format=$($bi.Format)"

function P($x, $y) { $i = $y * $stride + $x * 4; "B=$($px[$i]) G=$($px[$i+1]) R=$($px[$i+2]) A=$($px[$i+3])" }
Write-Host "corner (0,0)      : " (P 0 0)
Write-Host "corner (w-1,0)    : " (P ($w-1) 0)
Write-Host "corner (0,h-1)    : " (P 0 ($h-1))
Write-Host "corner (w-1,h-1)  : " (P ($w-1) ($h-1))
Write-Host "centre            : " (P ([int]($w/2)) ([int]($h/2)))

$a0 = 0; $a255 = 0
for ($i = 3; $i -lt $px.Length; $i += 4) { if ($px[$i] -eq 0) { $a0++ } elseif ($px[$i] -eq 255) { $a255++ } }
Write-Host "alpha: 0=$a0 255=$a255 total=$($w*$h)"

# bounding box of visible (alpha>8) pixels
$minX = $w; $maxX = -1; $minY = $h; $maxY = -1
for ($y = 0; $y -lt $h; $y++) {
  $row = $y * $stride
  for ($x = 0; $x -lt $w; $x++) {
    if ($px[$row + $x * 4 + 3] -gt 8) { if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }; if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y } }
  }
}
Write-Host "visible bbox: x=$minX..$maxX y=$minY..$maxY ($($maxX-$minX+1)x$($maxY-$minY+1))"

# dominant orange: sample a few points along the mark's left edge band
$colors = @{}
foreach ($pt in @(@(60, [int]($h/2)), @([int]($w/2), 90), @([int]($w-60), [int]($h/2)), @([int]($w/2), ($h-60)))) {
  $i = $pt[1] * $stride + $pt[0] * 4
  $key = "R=$($px[$i+2]) G=$($px[$i+1]) B=$($px[$i]) A=$($px[$i+3])"
  if (-not $colors.ContainsKey($key)) { $colors[$key] = 0 }
  $colors[$key]++
  Write-Host "sample ($($pt[0]),$($pt[1])): $key"
}
