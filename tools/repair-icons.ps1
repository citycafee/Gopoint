# Repairs the PWA icons: original icon-*.png files have alpha=0 on EVERY pixel
# (RGB data is intact). Rebuilds alpha from the rounded-square geometry, then
# regenerates the maskable icons and favicon.ico from the repaired artwork.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

Add-Type -AssemblyName PresentationCore, WindowsBase, System.Drawing

function Get-Rgba([string]$file) {
  $uri = New-Object System.Uri((Resolve-Path $file).Path)
  $bi = New-Object System.Windows.Media.Imaging.BitmapImage
  $bi.BeginInit(); $bi.CacheOption = 'OnLoad'; $bi.UriSource = $uri; $bi.EndInit()
  if ($bi.Format.ToString() -ne 'Bgra32') {
    $bi = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap($bi, [System.Windows.Media.PixelFormats]::Bgra32, $null, 0)
  }
  $stride = $bi.PixelWidth * 4
  $px = New-Object byte[] ($stride * $bi.PixelHeight)
  $bi.CopyPixels($px, $stride, 0)
  return ,@($px, $bi.PixelWidth, $bi.PixelHeight, $stride)
}

function Save-Bgra([byte[]]$px, [int]$w, [int]$h, [string]$file) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  [System.Runtime.InteropServices.Marshal]::Copy($px, 0, $data.Scan0, $px.Length)
  $bmp.UnlockBits($data)
  $bmp.Save((Join-Path (Get-Location) $file), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "wrote $file"
}

function Repair-Icon([string]$file) {
  $dec = Get-Rgba $file
  [byte[]]$px = $dec[0]; $w = $dec[1]; $h = $dec[2]; $stride = $dec[3]

  # 1) measure corner radius: top row, first pixel that is not (near) black
  $r = -1
  for ($x = 0; $x -lt $w; $x++) {
    $i = 0 * $stride + $x * 4   # BGRA
    if ($px[$i] -gt 60 -or $px[$i+1] -gt 60 -or $px[$i+2] -gt 60) { $r = $x; break }
  }
  if ($r -lt 4) { throw "Could not measure corner radius of $file" }
  # sanity: same radius measured from the left column
  $rCol = -1
  for ($y = 0; $y -lt $h; $y++) {
    $i = $y * $stride + 0 * 4
    if ($px[$i] -gt 60 -or $px[$i+1] -gt 60 -or $px[$i+2] -gt 60) { $rCol = $y; break }
  }
  Write-Host "$file : corner radius from top row=$r, left column=$rCol"
  $r = [Math]::Min($r, $rCol)

  # 2) rebuild alpha: opaque inside the rounded square, transparent outside
  $opaque = 0; $clear = 0
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      $a = 255
      if ($x -lt $r -and $y -lt $r)                     { $a = Corner-A $x $y $r }
      elseif ($x -ge ($w - $r) -and $y -lt $r)           { $a = Corner-A ($w - 1 - $x) $y $r }
      elseif ($x -lt $r -and $y -ge ($h - $r))           { $a = Corner-A $x ($h - 1 - $y) $r }
      elseif ($x -ge ($w - $r) -and $y -ge ($h - $r))    { $a = Corner-A ($w - 1 - $x) ($h - 1 - $y) $r }
      $px[$y * $stride + $x * 4 + 3] = [byte]$a
      if ($a -eq 255) { $opaque++ } else { $clear++ }
    }
  }
  Write-Host "  alpha rebuilt: opaque=$opaque transparent=$clear radius=$r"
  Save-Bgra $px $w $h $file
}

function Corner-A([int]$lx, [int]$ly, [int]$r) {
  # $lx/$ly measured from the icon's corner; rounded corner centre = ($r,$r)
  $dx = $lx - $r; $dy = $ly - $r
  $dist = [Math]::Sqrt($dx * $dx + $dy * $dy)
  $cov = $r - $dist + 0.5
  if ($cov -le 0) { return 0 }
  if ($cov -ge 1) { return 255 }
  return [int][Math]::Round(255 * $cov)
}

# --- backup originals, then repair in place (same filenames => no ref changes) ---
New-Item -ItemType Directory -Force -Path (Join-Path $root 'tools\backup') | Out-Null
foreach ($f in @('icon-192.png', 'icon-512.png')) {
  Copy-Item (Join-Path $root $f) (Join-Path $root "tools\backup\$f") -Force
  Repair-Icon $f
}

# --- regenerate maskable (full-bleed) icons + favicon from the repaired art ---
$src = [System.Drawing.Image]::FromFile((Resolve-Path 'icon-512.png'))
$orange = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 107, 0))

function New-Maskable([int]$size, [double]$scale) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
  $g.FillRectangle($orange, 0, 0, $size, $size)   # full bleed: required for maskable icons
  $w = [int]($size * $scale); $x = [int](($size - $w) / 2)
  $g.DrawImage($src, [float]$x, [float]$x, [float]$w, [float]$w)
  $g.Dispose()
  return $bmp
}

function Save-Png($bmp, [string]$name) {
  $bmp.Save((Join-Path (Get-Location) $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose(); Write-Host "wrote $name"
}

Save-Png (New-Maskable 192 0.66) 'icon-192-maskable.png'
Save-Png (New-Maskable 512 0.66) 'icon-512-maskable.png'

# favicon.ico : PNG-compressed ICO with 16/32/48 entries
$sizes = @(16, 32, 48)
$pngs = @()
foreach ($s in $sizes) {
  $b = New-Maskable $s 0.78
  $ms = New-Object System.IO.MemoryStream
  $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $pngs += ,@($ms.ToArray(), $s)
  $b.Dispose(); $ms.Dispose()
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
$bw.Dispose(); $ms.Dispose()
Write-Host 'wrote favicon.ico'
$src.Dispose()

# --- verification ---
foreach ($f in @('icon-192.png', 'icon-512.png', 'icon-192-maskable.png', 'icon-512-maskable.png')) {
  $dec = Get-Rgba $f
  [byte[]]$px = $dec[0]
  $a0 = 0; $a255 = 0
  for ($i = 3; $i -lt $px.Length; $i += 4) { if ($px[$i] -eq 0) { $a0++ } elseif ($px[$i] -eq 255) { $a255++ } }
  Write-Host ("VERIFY {0}: alpha0={1} alpha255={2} (total={3})" -f $f, $a0, $a255, ($px.Length / 4))
}
