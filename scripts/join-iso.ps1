# join-iso.ps1 — download, reassemble, and verify a split NixOS build from GitHub Releases
#
# Usage (PowerShell):
#   iwr "https://github.com/Cairnstew/nixos-config/releases/download/iso-<host>/join-iso.ps1" -OutFile join-iso.ps1; pwsh -File join-iso.ps1 <host>

param([Parameter(Mandatory)][string]$HostName)

$tag      = "iso-$HostName"
$repo     = "Cairnstew/nixos-config"
$api      = "https://api.github.com/repos/$repo/releases/tags/$tag"

# --- Download ---
Write-Host "==> Fetching asset list..."
$urls = (Invoke-RestMethod $api).assets.browser_download_url

Write-Host "==> Downloading assets in parallel..."
$jobs = $urls | ForEach-Object {
    $url  = $_
    $file = Split-Path $url -Leaf
    Start-Job { Invoke-WebRequest $using:url -OutFile $using:file }
}
$jobs | Wait-Job | Receive-Job

# --- Detect output type ---
$pattern  = "nixos-$HostName.*.sha256"
$checksum = Get-ChildItem $pattern | Select-Object -First 1

if (-not $checksum) {
    Write-Error "No checksum file matching '$pattern' found"
    exit 1
}

$base = $checksum.Name -replace '\.sha256$', ''

# --- Join ---
Write-Host "==> Locating segments for: $base"
$parts = Get-ChildItem "$base.part*" | Sort-Object Name

if ($parts.Count -eq 0) {
    Write-Error "Error: no files matching '$base.part*' found in $(Get-Location)"
    exit 1
}

Write-Host "    Found $($parts.Count) segment(s):"
foreach ($part in $parts) {
    $size = "{0:N2} MB" -f ($part.Length / 1MB)
    Write-Host "      $($part.Name)  ($size)"
}

Write-Host ""
Write-Host "==> Joining segments -> $base"
$out = [System.IO.File]::OpenWrite($base)
foreach ($part in $parts) {
    Write-Host "    Adding $($part.Name)..."
    $in = [System.IO.File]::OpenRead($part.FullName)
    $in.CopyTo($out)
    $in.Close()
}
$out.Close()
$size = "{0:N2} GB" -f ((Get-Item $base).Length / 1GB)
Write-Host "    Done. Size: $size"

# --- Verify ---
Write-Host ""
Write-Host "==> Verifying SHA-256 checksum..."
$expected = (Get-Content $checksum.FullName -Raw).Split(" ")[0].Trim()
$actual   = (Get-FileHash $base -Algorithm SHA256).Hash.ToLower()
if ($expected -eq $actual) {
    Write-Host ""
    Write-Host "==> OK - file is intact: $base"
} else {
    Write-Host ""
    Write-Error "ERROR: checksum mismatch!"
    Remove-Item $base
    exit 1
}
$jobs | Wait-Job | Receive-Job

# --- Join ---
Write-Host "==> Locating segments for: $iso"
$parts = Get-ChildItem "$iso.part*" | Sort-Object Name

if ($parts.Count -eq 0) {
    Write-Error "Error: no files matching '$iso.part*' found in $(Get-Location)"
    exit 1
}

Write-Host "    Found $($parts.Count) segment(s):"
foreach ($part in $parts) {
    $size = "{0:N2} MB" -f ($part.Length / 1MB)
    Write-Host "      $($part.Name)  ($size)"
}

Write-Host ""
Write-Host "==> Joining segments -> $iso"
$out = [System.IO.File]::OpenWrite($iso)
foreach ($part in $parts) {
    Write-Host "    Adding $($part.Name)..."
    $in = [System.IO.File]::OpenRead($part.FullName)
    $in.CopyTo($out)
    $in.Close()
}
$out.Close()
$size = "{0:N2} GB" -f ((Get-Item $iso).Length / 1GB)
Write-Host "    Done. Size: $size"

# --- Verify ---
Write-Host ""
if (Test-Path $checksum) {
    Write-Host "==> Verifying SHA-256 checksum..."
    $expected = (Get-Content $checksum -Raw).Split(" ")[0].Trim()
    $actual   = (Get-FileHash $iso -Algorithm SHA256).Hash.ToLower()
    if ($expected -eq $actual) {
        Write-Host ""
        Write-Host "==> OK - file is intact: $iso"
    } else {
        Write-Host ""
        Write-Error "ERROR: checksum mismatch!"
        Remove-Item $iso
        exit 1
    }
} else {
    Write-Warning "No checksum file found — skipping verification."
}