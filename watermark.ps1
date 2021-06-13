param (
    [Parameter(Mandatory = $true)][String]$Watermark,
    [Parameter(Mandatory = $true)][String]$Image,
    [Parameter(Mandatory = $true)][String]$Color,
    [String]$Output,
    [double]$Opacity = 1.0
)

# Example usage:
# .\watermark.ps1 -Watermark hbo -Color white -Image poster.png
# .\watermark.ps1 -Watermark showtime -Color black -Image poster.jpg

$watermarks = (Get-Content (Join-Path $PSScriptRoot "marks.json") | ConvertFrom-Json).watermarks
$logo = $watermarks | where { $_.name -eq $Watermark } | select -First 1
$logo_corner = $logo.corners | where { $_.direction -eq "nw" } | select -First 1

# normalize file paths
$logo_path = Join-Path $PSScriptRoot $logo.file
$img_path = Get-Item $Image
if ([string]::IsNullOrEmpty($Output)) {
    $output_image = Join-Path $img_path.DirectoryName "$($img_path.BaseName).$($logo.name)$($img_path.Extension)"
} else {
    New-Item $Output -Force | Out-Null
    $output_image = (Get-Item $Output).FullName
}

Write-Verbose "Using base image from $img_path"
Write-Verbose "Using watermark from $logo_path"
Write-Verbose "Output will be written to $output_image"

# img_scale is 1.0 on 2000 px wide image
$img_width = magick identify -format "%[fx:w]" $img_path
$img_scale = $img_width / 2000
$logo_height = $img_scale * $logo.normalized_height
$logo_scale = $logo_height / $logo.height

Write-Verbose "img_scale = $img_scale, logo_scale = $logo_scale"

# offset 110 px on 1.0 scale
$offset_x = ($img_scale * $logo_corner.offset.x) - ($logo_scale * $logo_corner.anchor.x)
$offset_y = ($img_scale * $logo_corner.offset.y) - ($logo_scale * $logo_corner.anchor.y)

Write-Verbose "offset = x:$offset_x, y:$offset_y"

# rasterize logo
$rasterizedLogo = "$($logo.name).png"
magick convert `
    -background none `
    -geometry x$logo_height `
    -fill $Color -colorize 100 `
    -channel A -evaluate multiply $Opacity +channel `
    "$logo_path" $rasterizedLogo

# composite onto image
magick composite -gravity NorthWest -geometry +$offset_x+$offset_y $rasterizedLogo $Image $output_image

# delete rasterized logo
Remove-Item $rasterizedLogo

Write-Host "Watermarked image saved as $output_image."
