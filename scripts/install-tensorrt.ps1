<#
.SYNOPSIS
Install TensorRT 11.2.1 from a ZIP into a chosen root.

.DESCRIPTION
If $env:TENSORRT_HOME exists and the path is valid, exits.
Otherwise downloads the specified TensorRT zip, extracts into ExtractRoot,
sets TENSORRT_HOME and adds <root>\bin to system PATH. Also sets TENSORRT_INCLUDE and TENSORRT_LIB.

.PARAMETER Admin
If provided, verifies elevation.

.PARAMETER DownloadURL
TensorRT Windows zip URL for CUDA 13.3 by default.

.PARAMETER ExtractRoot
Target root for TensorRT. Defaults to $env:TENSORRT_HOME if set; otherwise
"C:\Program Files\NVIDIA\TensorRT\11.2.1".

.EXAMPLE
.\install-tensorrt.ps1 -Admin
#>

[CmdletBinding()]
param(
  [switch]$Admin,
  [Parameter()][ValidateNotNullOrEmpty()][string]$DownloadURL = "https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/11.2.1/zip/TensorRT-11.2.1.0.Windows.win10.cuda-13.3.zip",
  [Parameter()][string]$ExtractRoot = $(if ($env:TENSORRT_HOME) { $env:TENSORRT_HOME } else { "C:\Program Files\NVIDIA\TensorRT\11.2.1" })
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

# Already installed?
if ($env:TENSORRT_HOME -and (Test-Path -LiteralPath $env:TENSORRT_HOME)) {
  Write-Host "[tensorrt] Found at $env:TENSORRT_HOME";
  Write-Output "$env:TENSORRT_HOME"
  exit 0
}

function Add-PathOnce([string]$PathToAdd) {
  $scope = if ($Admin) { 'Machine' } else { 'User' }
  $cur = [Environment]::GetEnvironmentVariable('Path', $scope) -split ';' | Where-Object { $_ }
  if ($cur -notcontains $PathToAdd) {
    [Environment]::SetEnvironmentVariable('Path', (($cur + $PathToAdd) -join ';'), $scope)
  }
}

function ChangeEnvironmentVariable {
  param (
    [string]$InstallRoot
  )
  $scope = if ($Admin) { 'Machine' } else { 'User' }
  [Environment]::SetEnvironmentVariable('TENSORRT_HOME', $InstallRoot, $scope)
  [Environment]::SetEnvironmentVariable('TENSORRT_INCLUDE', (Join-Path $InstallRoot 'include'), $scope)
  [Environment]::SetEnvironmentVariable('TENSORRT_LIB', (Join-Path $InstallRoot 'lib'), $scope)
  Add-PathOnce (Join-Path $InstallRoot 'bin')
  Write-Host "[tensorrt] Using $InstallRoot"
  Write-Output "$InstallRoot"
}

if (Test-Path -LiteralPath $ExtractRoot) {
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
Write-Host "[tensorrt] Downloading $DownloadURL"
DownloadToFile -Uri $DownloadURL -OutFile $tempZip

New-Item -ItemType Directory -Force -Path $ExtractRoot | Out-Null
Expand-Archive -Path $tempZip -DestinationPath $ExtractRoot -Force

# After extraction, the archive is expected to contain a single top-level directory (e.g., "TensorRT-11.2.1") inside $ExtractRoot.
# That directory should contain the actual TensorRT files, including a 'bin' subdirectory.
$inner = Get-ChildItem -Directory $ExtractRoot | Select-Object -First 1
if ($inner -and (Test-Path (Join-Path $inner.FullName 'bin'))) {
  # If the only directory in $ExtractRoot contains 'bin', flatten the structure by moving its contents up one level.
  # This handles archives that wrap all files in a single directory.
  Get-ChildItem $inner.FullName | Move-Item -Destination $ExtractRoot -Force
  Remove-Item $inner.FullName -Recurse -Force
}

if (-not (Test-Path (Join-Path $ExtractRoot 'bin'))) { throw "[tensorrt] Unexpected archive layout in $ExtractRoot" }

ChangeEnvironmentVariable -InstallRoot $ExtractRoot
