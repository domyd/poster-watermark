param (
    [Parameter(Mandatory = $true)][String]$Image,
    [String]$Watermark,
    [String]$Color,
    [String]$Output,
    [double]$Opacity = 0.0,
    [switch]$SaveSettings = $false
)

# Example usage:
# .\watermark.ps1 -Watermark hbo -Color white -Image poster.png
# .\watermark.ps1 -Watermark showtime -Color black -Image poster.jpg

$img_path = Get-Item $Image
$settings = @{
    watermark = [string]::Empty
    color     = [string]::Empty
    opacity   = 1.0
    output    = [string]::Empty
}

# check if watermark.json exists for image file
$watermark_json_path = Join-Path $img_path.DirectoryName "$($img_path.BaseName).watermark.json"
if (Test-Path $watermark_json_path) {
    # use settings from watermark.json file
    Write-Host "Using settings from $($img_path.BaseName).watermark.json in target directory."
    $settings_json = Get-Content $watermark_json_path | ConvertFrom-Json
    $settings.watermark = $settings_json.watermark
    $settings.color = $settings_json.color
    $settings.opacity = $settings_json.opacity
    $settings.output = Join-Path $img_path.DirectoryName $settings_json.filename
}

if (-not [string]::IsNullOrEmpty($Watermark)) {
    $settings.watermark = $Watermark
}

if (-not [string]::IsNullOrEmpty($Color)) {
    $settings.color = $Color
}

if ($Opacity -gt 0.0) {
    $settings.opacity = $Opacity
}

$watermarks = (Get-Content (Join-Path $PSScriptRoot "marks.json") | ConvertFrom-Json).watermarks
$logo = $watermarks | Where-Object { $_.name -eq $settings.watermark } | Select-Object -First 1
$logo_corner = $logo.corners | Where-Object { $_.direction -eq "nw" } | Select-Object -First 1
$logo_path = Join-Path $PSScriptRoot $logo.file

if (-not [string]::IsNullOrEmpty($Output)) {
    New-Item $Output -Force | Out-Null
    $settings.output = (Get-Item $Output).FullName
}
elseif ([string]::IsNullOrEmpty($settings.output)) {
    $settings.output = Join-Path $img_path.DirectoryName "$($img_path.BaseName).$($logo.name)$($img_path.Extension)"
}

Write-Verbose "Using base image from $img_path"
Write-Verbose "Using watermark '$($settings.watermark)' from $logo_path"
Write-Verbose "Output will be written to $($settings.output)"
Write-Verbose "settings: color = $($settings.color), opacity = $($settings.opacity)"

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
$tmpFile = New-TemporaryFile
$rasterizedLogo = Join-Path $tmpFile.DirectoryName "$($tmpFile.BaseName).png"
Move-Item $tmpFile -Destination $rasterizedLogo
Write-Verbose "rasterized logo as $rasterizedLogo"
magick convert `
    -background none `
    -geometry x$logo_height `
    -fill $settings.color -colorize 100 `
    -channel A -evaluate multiply $settings.opacity +channel `
    "$logo_path" "$rasterizedLogo"

# composite onto image
magick composite -gravity NorthWest -geometry +$offset_x+$offset_y "$rasterizedLogo" "$img_path" "$($settings.output)"

# save settings maybe
if ($SaveSettings) {
    Write-Host "Saving watermark settings to $watermark_json_path"
    $filename = (Get-Item $settings.output).Name
    $out_settings = @{
        watermark = $settings.watermark
        opacity   = $settings.opacity
        color     = $settings.color
        filename  = $filename
    }
    ConvertTo-Json $out_settings | Out-File $watermark_json_path
}

# delete rasterized logo
Remove-Item $rasterizedLogo

Write-Host "Watermarked image saved as $($settings.output)."
