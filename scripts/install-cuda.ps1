<#
.SYNOPSIS
Install CUDA 13.3.x silently with selected components.

.DESCRIPTION
Checks $env:CUDA_PATH. If valid, exits. Otherwise downloads the CUDA installer,
installs only the requested subpackages in silent mode, and configures env vars.
Defaults now include profiler/debug components for CI.

.PARAMETER Admin
If provided, verify elevation.

.PARAMETER DownloadURL
CUDA 13.3.x local installer URL. Defaults to NVIDIA 13.3.0 full installer.

.PARAMETER InstallRoot
Target CUDA root. Defaults to $env:CUDA_PATH or the standard v13.3 path.

.PARAMETER Components
CUDA subpackages to install. Defaults to a CI set for CUDA 13.3.

.EXAMPLE
.\install-cuda.ps1 -Admin
.EXAMPLE
.\install-cuda.ps1 -Components nvcc_13.3,cudart_13.3,cublas_13.3
#>

[CmdletBinding()]
param(
  [switch]$Admin,
  [Parameter()][ValidateNotNullOrEmpty()][string]$DownloadURL = "https://developer.download.nvidia.com/compute/cuda/13.3.0/local_installers/cuda_13.3.0_windows.exe",
  [Parameter()][string]$InstallRoot = $(if ($env:CUDA_PATH) { $env:CUDA_PATH } else { "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.3" }),
  [Parameter()][string[]]$Components = @(
    'nvcc_13.3', 'cudart_13.3', 'nvrtc_13.3', 'nvrtc_dev_13.3', 'nvjitlink_13.3',
    'cublas_13.3', 'cublas_dev_13.3', 'cufft_13.3', 'cufft_dev_13.3',
    'curand_13.3', 'curand_dev_13.3', 'cusolver_13.3', 'cusolver_dev_13.3',
    'cusparse_13.3', 'cusparse_dev_13.3', 'thrust_13.3', 'nvtx_13.3',
    'nvdisasm_13.3', 'nvprune_13.3', 'nvfatbin_13.3', 'cuobjdump_13.3',
    'cupti_13.3', 'cuda_profiler_api_13.3', 'opencl_13.3', 'sanitizer_13.3'
  )
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
    Write-Error "[cuda] Download failed: $Uri"
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
if ($env:CUDA_PATH -and (Test-Path -LiteralPath $env:CUDA_PATH)) {
  Write-Host "[cuda] Found at $env:CUDA_PATH";
  Write-Output "$env:CUDA_PATH"
  exit 0
}

function ChangeEnvironmentVariable {
  param (
    [string]$InstallRoot
  )
  [Environment]::SetEnvironmentVariable('CUDA_PATH', $InstallRoot, 'Machine')
  Add-PathOnce (Join-Path $InstallRoot 'bin')
  Add-PathOnce (Join-Path $InstallRoot 'libnvvp')
  Write-Host "[cuda] Using $InstallRoot"
  Write-Output "$InstallRoot"
}
if (Test-Path -LiteralPath $InstallRoot) {
  ChangeEnvironmentVariable -InstallRoot $InstallRoot
  exit 0
}

# Download installer
$temp = Join-Path $env:TEMP ("cuda-" + [guid]::NewGuid() + ".exe")
Write-Host "[cuda] Downloading $DownloadURL"
DownloadToFile -Uri $DownloadURL -OutFile $temp

# Silent install with explicit components
# The NVIDIA installer expects the -n flag to be followed by a space-separated list of component names.
# If any component name contains spaces, it must be quoted. We quote each component name to be robust.
$compArgs = $Components | ForEach-Object { '"{0}"' -f $_ } |  Join-String " "
$arguments = "-s -n $compArgs"

Write-Host "[cuda] Installing selected components:"
$Components | ForEach-Object { Write-Host "  - $_" }

Start-Process -FilePath $temp -ArgumentList $arguments -Wait -NoNewWindow

# Detect root and persist env
$defaultRoot = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.3"
$detect = @( $InstallRoot, $defaultRoot, $env:CUDA_PATH ) |
Where-Object { $_ } | Select-Object -Unique |
Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $detect) { throw "[cuda] Install not found. Checked: $InstallRoot, $defaultRoot" }

ChangeEnvironmentVariable -InstallRoot $detect