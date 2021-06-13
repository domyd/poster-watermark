param (
    [String]$Watermark,
    [String]$Image,
    [String]$Color
)

# Example usage:
# .\watermark.ps1 -Watermark hbo -Color white -Image poster.png
# .\watermark.ps1 -Watermark showtime -Color black -Image poster.jpg

$watermarks = (Get-Content .\marks.json | ConvertFrom-Json).watermarks
$logo = $watermarks | where { $_.name -eq $Watermark } | select -First 1
$logo_offset = ($logo.corners | where { $_.direction -eq "nw" } | select -First 1).offset

# scale 1.0 on 2000 width image
$img_width = magick identify -format "%[fx:w]" $Image
$scale = $img_width / 2000

# logo height is 90 px on 1.0 scale
$logo_height = $scale * 90
$logo_scale = $logo_height / $logo.height

# offset 110 px on 1.0 scale
$offset_x = ($scale * 110) - ($logo_scale * $logo_offset.x)
$offset_y = ($scale * 110) - ($logo_scale * $logo_offset.y)

# rasterize logo
$rasterizedLogo = "$($logo.name).png"
magick convert -background none -geometry x$logo_height -fill $Color -colorize 100 "$($logo.file)" $rasterizedLogo

# composite onto image
$output_image = "$([System.IO.Path]::GetFileNameWithoutExtension($Image)).watermarked$([System.IO.Path]::GetExtension($Image))"
magick composite -gravity NorthWest -geometry +$offset_x+$offset_y $rasterizedLogo $Image $output_image

# delete rasterized logo
Remove-Item $rasterizedLogo
