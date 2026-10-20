$ErrorActionPreference = 'Stop'
Set-Location D:\milgo1\Downloads\Gopoint.app
Add-Type -AssemblyName PresentationCore, WindowsBase, System.Drawing

foreach ($f in @('icon-192.png', 'icon-512.png')) {
  $uri = New-Object System.Uri((Resolve-Path $f).Path)
  $bi = New-Object System.Windows.Media.Imaging.BitmapImage
  $bi.BeginInit(); $bi.CacheOption = 'OnLoad'; $bi.UriSource = $uri; $bi.EndInit()
  $conv = $bi
  if ($bi.Format.ToString() -ne 'Bgra32') {
    $conv = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap($bi, [System.Windows.Media.PixelFormats]::Bgra32, $null, 0)
  }
  $w = $conv.PixelWidth; $h = $conv.PixelHeight
  $stride = $w * 4
  $px = New-Object byte[] ($stride * $h)
  $conv.CopyPixels($px, $stride, 0)
  $fmt = $conv.Format
  # sample: corner (0,0), centre, and a few grid points -> RGBA order (Bgra32 => B,G,R,A)
  function At($x, $y) {
    $i = $y * $stride + $x * 4
    "($x,$y) B=$($px[$i]) G=$($px[$i+1]) R=$($px[$i+2]) A=$($px[$i+3])"
  }
  Write-Host "$f WPF decoder: ${w}x$h format=$fmt"
  Write-Host "  " (At 0 0)
  Write-Host "  " (At ([int]($w/2)) ([int]($h/2)))
  Write-Host "  " (At ([int]($w/3)) ([int]($h/4)))
  # alpha histogram
  $a0 = 0; $a255 = 0; $other = 0
  for ($i = 3; $i -lt $px.Length; $i += 4) {
    $a = $px[$i]
    if ($a -eq 0) { $a0++ } elseif ($a -eq 255) { $a255++ } else { $other++ }
  }
  Write-Host "  alpha: 0=$a0  255=$a255  other=$other (total=$($w*$h))"
}
