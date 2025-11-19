<#
.SYNOPSIS
Install TensorRT 10.14.x from a ZIP into a chosen root.

.DESCRIPTION
If $env:TENSORRT_HOME exists and the path is valid, exits.
Otherwise downloads the specified TensorRT zip, extracts into ExtractRoot,
sets TENSORRT_HOME and adds <root>\bin to system PATH. Also sets TENSORRT_INCLUDE and TENSORRT_LIB.

.PARAMETER Admin
If provided, verifies elevation.

.PARAMETER DownloadURL
TensorRT Windows zip URL for CUDA 12.9 by default.

.PARAMETER ExtractRoot
Target root for TensorRT. Defaults to $env:TENSORRT_HOME if set; otherwise
"C:\Program Files\NVIDIA\TensorRT\10.14.1".

.EXAMPLE
.\install-tensorrt.ps1 -Admin
#>

[CmdletBinding()]
param(
  [switch]$Admin,
  [Parameter()][ValidateNotNullOrEmpty()][string]$DownloadURL = "https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/10.14.1/zip/TensorRT-10.14.1.48.Windows.win10.cuda-12.9.zip",
  [Parameter()][string]$ExtractRoot = $(if ($env:TENSORRT_HOME) { $env:TENSORRT_HOME } else { "C:\Program Files\NVIDIA\TensorRT\10.14.1" })
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

function DownloadToFile([string]$Uri, [string]$OutFile) {
  try {
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -TimeoutSec 600
  }
  catch {
    Write-Error "[tensorrt] Download failed: $Uri"
    exit 1
  }
}

function Add-PathOnce([string]$PathToAdd) {
  $cur = [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' | Where-Object { $_ }
  if ($cur -notcontains $PathToAdd) {
    [Environment]::SetEnvironmentVariable('Path', (($cur + $PathToAdd) -join ';'), 'Machine')
  }
}

# Already installed?
if ($env:TENSORRT_HOME -and (Test-Path -LiteralPath $env:TENSORRT_HOME)) {
  Write-Host "[tensorrt] Found at $env:TENSORRT_HOME";
  Write-Output "$env:TENSORRT_HOME"
  exit 0
}

function ChangeEnvironmentVariable {
  param (
    [string]$InstallRoot
  )
  [Environment]::SetEnvironmentVariable('TENSORRT_HOME', $InstallRoot, 'Machine')
  [Environment]::SetEnvironmentVariable('TENSORRT_INCLUDE', (Join-Path $InstallRoot 'include'), 'Machine')
  [Environment]::SetEnvironmentVariable('TENSORRT_LIB', (Join-Path $InstallRoot 'lib'), 'Machine')
  Add-PathOnce (Join-Path $InstallRoot 'bin')
  Write-Host "[tensorrt] Using $InstallRoot"
  Write-Output "$InstallRoot"
}

if (Test-Path -LiteralPath $ExtractRoot) {
  ChangeEnvironmentVariable -InstallRoot $ExtractRoot
  exit 0
}

$tempZip = Join-Path $env:TEMP ("tensorrt-" + [guid]::NewGuid() + ".zip")
Write-Host "[tensorrt] Downloading $DownloadURL"
DownloadToFile -Uri $DownloadURL -OutFile $tempZip

New-Item -ItemType Directory -Force -Path $ExtractRoot | Out-Null
Expand-Archive -Path $tempZip -DestinationPath $ExtractRoot -Force

$inner = Get-ChildItem -Directory $ExtractRoot | Select-Object -First 1
if ($inner -and (Test-Path (Join-Path $inner.FullName 'bin'))) {
  $others = Get-ChildItem $ExtractRoot
  if ($others.Count -eq 1) {
    Get-ChildItem $inner.FullName | Move-Item -Destination $ExtractRoot -Force
    Remove-Item $inner.FullName -Recurse -Force
  }
}

if (-not (Test-Path (Join-Path $ExtractRoot 'bin'))) { throw "[tensorrt] Unexpected archive layout in $ExtractRoot" }

ChangeEnvironmentVariable -InstallRoot $ExtractRoot
