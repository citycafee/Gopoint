# Builds every app icon from the brand logo at E:\logo.png.
# The source PNG stores the background AND the white circle as RGB-white with
# alpha=0, so each canvas is filled white inside the rounded-square silhouette
# first, then the logo artwork is composited on top.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root
Add-Type -AssemblyName System.Drawing, PresentationCore, WindowsBase

$srcPath = 'E:\logo.png'
if (-not (Test-Path $srcPath)) { throw "Logo not found: $srcPath" }

# ---------- decode ----------
$uri = New-Object System.Uri((Resolve-Path $srcPath).Path)
$bi = New-Object System.Windows.Media.Imaging.BitmapImage
$bi.BeginInit(); $bi.CacheOption = 'OnLoad'; $bi.UriSource = $uri; $bi.EndInit()
if ($bi.Format.ToString() -ne 'Bgra32') { $bi = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap($bi, [System.Windows.Media.PixelFormats]::Bgra32, $null, 0) }
$srcW = $bi.PixelWidth; $srcH = $bi.PixelHeight; $srcStride = $srcW * 4
$srcPx = New-Object byte[] ($srcStride * $srcH)
$bi.CopyPixels($srcPx, $srcStride, 0)
function Src-Pix([int]$x, [int]$y) { $i = $y * $srcStride + $x * 4; return ,@($srcPx[$i], $srcPx[$i+1], $srcPx[$i+2], $srcPx[$i+3]) }

# ---------- visible bounding box of the mark ----------
$minX = $srcW; $maxX = -1; $minY = $srcH; $maxY = -1
for ($y = 0; $y -lt $srcH; $y++) {
  $row = $y * $srcStride
  for ($x = 0; $x -lt $srcW; $x++) {
    if ($srcPx[$row + $x * 4 + 3] -gt 8) {
      if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
$W = $maxX - $minX + 1; $H = $maxY - $minY + 1
Write-Host "logo ${srcW}x${srcH}, mark bbox ($minX,$minY) ${W}x${H}"

$rTop = -1
for ($x = 0; $x -lt $W; $x++) { $p = Src-Pix ($minX + $x) $minY; if ($p[3] -gt 8) { $rTop = $x; break } }
$rLeft = -1
for ($y = 0; $y -lt $H; $y++) { $p = Src-Pix $minX ($minY + $y); if ($p[3] -gt 8) { $rLeft = $y; break } }
$r = [Math]::Min($rTop, $rLeft)
Write-Host "corner radius: top=$rTop left=$rLeft -> using $r"

# ---------- sample the brand gradient ----------
function Avg-Orange([int]$x0, [int]$y0, [int]$x1, [int]$y1) {
  $sr = 0; $sg = 0; $sb = 0; $n = 0
  for ($y = $y0; $y -le $y1; $y += 2) {
    for ($x = $x0; $x -le $x1; $x += 2) {
      $p = Src-Pix ($minX + $x) ($minY + $y)
      if ($p[3] -gt 200 -and $p[2] -gt 180 -and $p[1] -ge 60 -and $p[1] -le 200 -and $p[0] -lt 130) { $sr += $p[2]; $sg += $p[1]; $sb += $p[0]; $n++ }
    }
  }
  if ($n -eq 0) { return $null }
  return ,@([int]($sr/$n), [int]($sg/$n), [int]($sb/$n), $n)
}
$c = [int]($W / 2)
$top = Avg-Orange ([int]($c*0.30)) ([int]($c*0.02)) ([int]($c*0.70)) ([int]($c*0.12))
$bot = Avg-Orange ([int]($c*0.30)) ([int]($c*0.88)) ([int]($c*0.70)) ([int]($c*0.98))
if ($null -eq $top -or $null -eq $bot) { throw 'Could not sample the brand orange' }
Write-Host "orange top = RGB($($top[0]),$($top[1]),$($top[2]))  bottom = RGB($($bot[0]),$($bot[1]),$($bot[2]))"
$tlCol = [System.Drawing.Color]::FromArgb(255, $top[0], $top[1], $top[2])
$brCol = [System.Drawing.Color]::FromArgb(255, $bot[0], $bot[1], $bot[2])

# ---------- draw the mark cropped to its bounding box ----------
$markRect = New-Object System.Drawing.Rectangle($minX, $minY, $W, $H)
$srcBmp = New-Object System.Drawing.Bitmap((Resolve-Path $srcPath).Path)

function New-Canvas([int]$size) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = 'HighQuality'
  $g.CompositingQuality = 'HighQuality'
  return ,@($bmp, $g)
}

function Rounded-Path([int]$size, [double]$rad) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = [float](2 * $rad)
  $p.AddArc(0, 0, $d, $d, 180, 90)
  $p.AddArc([float]($size - 2*$rad), 0, $d, $d, 270, 90)
  $p.AddArc([float]($size - 2*$rad), [float]($size - 2*$rad), $d, $d, 0, 90)
  $p.AddArc(0, [float]($size - 2*$rad), $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

# $gradient = $true  -> full-bleed brand gradient behind the mark (maskable / apple-touch)
function Render-Icon($g, [int]$size, [bool]$gradient) {
  if ($gradient) {
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
      (New-Object System.Drawing.PointF(0, 0)), (New-Object System.Drawing.SizeF($size, $size)), $tlCol, $brCol)
    $g.FillRectangle($brush, 0, 0, $size, $size)
    $brush.Dispose()
  } else {
    $g.Clear([System.Drawing.Color]::Transparent)
  }
  # opaque white base inside the mark's rounded-square silhouette
  $rad = $r * $size / $W
  $path = Rounded-Path $size $rad
  $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
  $g.FillPath($white, $path)
  $white.Dispose(); $path.Dispose()
  # artwork on top (its transparent circle/background lets the white base show)
  $g.DrawImage($srcBmp, (New-Object System.Drawing.Rectangle(0, 0, $size, $size)), $markRect, [System.Drawing.GraphicsUnit]::Pixel)
}

function Save-Bmp($bmp, [string]$name) {
  $bmp.Save((Join-Path (Get-Location) $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose(); Write-Host "wrote $name"
}

foreach ($pair in @(@(512, 'icon-512.png', $false), @(192, 'icon-192.png', $false),
                    @(512, 'icon-512-maskable.png', $true), @(192, 'icon-192-maskable.png', $true),
                    @(180, 'apple-touch-icon.png', $true))) {
  $c2 = New-Canvas $pair[0]
  Render-Icon $c2[1] $pair[0] $pair[2]
  $c2[1].Dispose()
  Save-Bmp $c2[0] $pair[1]
}

# favicon.ico
$pngs = @()
foreach ($s in @(16, 32, 48)) {
  $c3 = New-Canvas $s
  Render-Icon $c3[1] $s $false
  $c3[1].Dispose()
  $ms = New-Object System.IO.MemoryStream
  $c3[0].Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $pngs += ,@($ms.ToArray(), $s)
  $c3[0].Dispose(); $ms.Dispose()
}
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$pngs.Count)
$offset = 6 + 16 * $pngs.Count
foreach ($e in $pngs) {
  $d = $e[0]; $s = $e[1]
  $bw.Write([byte]$(if ($s -ge 256) { 0 } else { $s }))
  $bw.Write([byte]$(if ($s -ge 256) { 0 } else { $s }))
  $bw.Write([byte]0); $bw.Write([byte]0)
  $bw.Write([uint16]1); $bw.Write([uint16]32)
  $bw.Write([uint32]$d.Length); $bw.Write([uint32]$offset)
  $offset += $d.Length
}
foreach ($e in $pngs) { $bw.Write($e[0]) }
$bw.Flush()
[System.IO.File]::WriteAllBytes((Join-Path (Get-Location) 'favicon.ico'), $ms.ToArray())
$bw.Dispose(); $ms.Dispose(); $srcBmp.Dispose()
Write-Host 'wrote favicon.ico'

# ---------- verification ----------
foreach ($f in @('icon-192.png', 'icon-512.png', 'icon-192-maskable.png', 'icon-512-maskable.png', 'apple-touch-icon.png')) {
  $b2 = New-Object System.Drawing.Bitmap((Join-Path (Get-Location) $f))
  $b2w = $b2.Width; $b2h = $b2.Height
  $rr = New-Object System.Drawing.Rectangle(0, 0, $b2w, $b2h)
  $d2 = $b2.LockBits($rr, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $buf = New-Object byte[] ($b2w * 4 * $b2h)
  [System.Runtime.InteropServices.Marshal]::Copy($d2.Scan0, $buf, 0, $buf.Length)
  $b2.UnlockBits($d2); $b2.Dispose()
  $a0 = 0; $a255 = 0
  for ($i = 3; $i -lt $buf.Length; $i += 4) { if ($buf[$i] -eq 0) { $a0++ } elseif ($buf[$i] -eq 255) { $a255++ } }
  Write-Host ("VERIFY {0}: {1}x{2} alpha0={3} alpha255={4}" -f $f, $b2w, $b2h, $a0, $a255)
}
