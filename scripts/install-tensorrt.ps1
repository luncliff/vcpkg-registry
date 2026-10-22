<#
.SYNOPSIS
Install TensorRT 11.4.0 for CUDA 13.4 from a ZIP into a chosen root.

.DESCRIPTION
If $env:TENSORRT_HOME exists and the path is valid, exits.
Otherwise downloads the specified TensorRT zip, extracts into ExtractRoot,
sets TENSORRT_HOME and adds <root>\bin to system PATH. Also sets TENSORRT_INCLUDE and TENSORRT_LIB.

.PARAMETER Admin
If provided, verifies elevation.

.PARAMETER DownloadURL
TensorRT Windows zip URL for CUDA 13.4 by default.

.PARAMETER ExtractRoot
Target root for TensorRT. Defaults to $env:TENSORRT_HOME if set; otherwise
"C:\Program Files\NVIDIA\TensorRT\11.4.0".

.PARAMETER VerifyDownload
Check the selected artifact with an HTTP HEAD request without installing TensorRT.

.EXAMPLE
.\install-tensorrt.ps1 -Admin
.EXAMPLE
.\install-tensorrt.ps1 -VerifyDownload
#>

[CmdletBinding()]
param(
  [switch]$Admin,
  [Parameter()][ValidateNotNullOrEmpty()][string]$DownloadURL = "https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/11.4.0/zip/TensorRT-Enterprise-11.4.0.106-Windows-amd64-cuda-13.4-Release-external.zip",
  [Parameter()][string]$ExtractRoot = $(if ($env:TENSORRT_HOME) { $env:TENSORRT_HOME } else { "C:\Program Files\NVIDIA\TensorRT\11.4.0" }),
  [switch]$VerifyDownload
)

$ErrorActionPreference = 'Stop'

function EnsureAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = [Security.Principal.WindowsPrincipal]::new($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    throw "Must run elevated. Re-run in an Administrator PowerShell."
  }
}
if ($Admin) { EnsureAdmin }

if ($VerifyDownload) {
  $response = Invoke-WebRequest -Uri $DownloadURL -Method Head -TimeoutSec 60
  if ($response.StatusCode -ne 200) {
    throw "[tensorrt] Artifact check failed: $DownloadURL (HTTP $($response.StatusCode))"
  }
  Write-Host "[tensorrt] Verified TensorRT artifact: $DownloadURL"
  return
}

function Test-TensorRtInstallation([string]$Root) {
  if (-not $Root) { return $false }
  $bin = Join-Path $Root 'bin'
  $inc = Join-Path $Root 'include'
  $lib = Join-Path $Root 'lib'
  if (-not (Test-Path -LiteralPath $bin)) { return $false }
  if (-not (Test-Path -LiteralPath $inc)) { return $false }
  if (-not (Test-Path -LiteralPath $lib)) { return $false }
  $headerFound = Test-Path -LiteralPath (Join-Path $inc 'NvInfer.h')
  $libFound = Get-ChildItem -LiteralPath $lib -Filter 'nvinfer*.lib' -File -ErrorAction SilentlyContinue | Select-Object -First 1
  return [bool]($headerFound -and $libFound)
}

# Already installed?
if (Test-TensorRtInstallation $env:TENSORRT_HOME) {
  Write-Host "[tensorrt] Found at $env:TENSORRT_HOME";
  Write-Output "$env:TENSORRT_HOME"
  exit 0
}

function Add-PathOnce([string]$PathToAdd) {
  try {
    $cur = [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' | Where-Object { $_ }
    if ($cur -notcontains $PathToAdd) {
      [Environment]::SetEnvironmentVariable('Path', (($cur + $PathToAdd) -join ';'), 'Machine')
    }
  }
  catch {
    throw "[tensorrt] Failed to update machine PATH. Run this script in an Administrator PowerShell."
  }
}

function ChangeEnvironmentVariable {
  param (
    [string]$InstallRoot
  )
  try {
    [Environment]::SetEnvironmentVariable('TENSORRT_HOME', $InstallRoot, 'Machine')
    [Environment]::SetEnvironmentVariable('TENSORRT_INCLUDE', (Join-Path $InstallRoot 'include'), 'Machine')
    [Environment]::SetEnvironmentVariable('TENSORRT_LIB', (Join-Path $InstallRoot 'lib'), 'Machine')
  }
  catch {
    throw "[tensorrt] Failed to set TensorRT environment variables at machine scope. Run this script in an Administrator PowerShell."
  }
  Add-PathOnce (Join-Path $InstallRoot 'bin')
  Write-Host "[tensorrt] Using $InstallRoot"
  Write-Output "$InstallRoot"
}

if (Test-TensorRtInstallation $ExtractRoot) {
  ChangeEnvironmentVariable -InstallRoot $ExtractRoot
  exit 0
}

function DownloadToFile([string]$Uri, [string]$OutFile) {
  try {
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -TimeoutSec 600
  }
  catch {
    Write-Error "[tensorrt] Download failed: $Uri"
    exit 1
  }
}

$tempZip = Join-Path $env:TEMP ("tensorrt-" + [guid]::NewGuid() + ".zip")
try {
  Write-Host "[tensorrt] Downloading $DownloadURL"
  DownloadToFile -Uri $DownloadURL -OutFile $tempZip

  New-Item -ItemType Directory -Force -Path $ExtractRoot | Out-Null
  Expand-Archive -Path $tempZip -DestinationPath $ExtractRoot -Force

  # After extraction, the archive is expected to contain a single top-level directory (e.g., "TensorRT-11.4.0.106") inside $ExtractRoot.
  # That directory should contain the actual TensorRT files, including a 'bin' subdirectory.
  $inner = Get-ChildItem -Directory $ExtractRoot | Select-Object -First 1
  if ($inner -and (Test-Path (Join-Path $inner.FullName 'bin'))) {
    # If the only directory in $ExtractRoot contains 'bin', flatten the structure by moving its contents up one level.
    # This handles archives that wrap all files in a single directory.
    Get-ChildItem $inner.FullName | Move-Item -Destination $ExtractRoot -Force
    Remove-Item $inner.FullName -Recurse -Force
  }

  if (-not (Test-TensorRtInstallation $ExtractRoot)) { throw "[tensorrt] Unexpected archive layout in $ExtractRoot" }
  Set-Content -LiteralPath (Join-Path $ExtractRoot '.vcpkg-tensorrt-install') -Value 'TensorRT archive installation'
  ChangeEnvironmentVariable -InstallRoot $ExtractRoot
}
finally {
  if (Test-Path -LiteralPath $tempZip) { Remove-Item -LiteralPath $tempZip -Force }
}
