<#
.SYNOPSIS
Install CUDA 13.4.x silently with selected components.

.DESCRIPTION
Checks $env:CUDA_PATH. If valid, exits. Otherwise downloads the CUDA installer,
installs only the requested subpackages in silent mode, and configures env vars.
Defaults include profiler/debug components for CI; the removed nvprof component is omitted.

.PARAMETER Admin
If provided, verify elevation.

.PARAMETER DownloadURL
CUDA 13.4.x local installer URL. Defaults to NVIDIA 13.4.3 for Windows x86_64.

.PARAMETER InstallRoot
Target CUDA root. Defaults to $env:CUDA_PATH or the standard v13.4 path.

.PARAMETER Components
CUDA subpackages to install. Defaults to a CI set:
nvcc_13.4, cudart_13.4, nvrtc_13.4, nvrtc_dev_13.4, nvjitlink_13.4,
cublas_13.4, cublas_dev_13.4, cufft_13.4, cufft_dev_13.4,
curand_13.4, curand_dev_13.4, cusolver_13.4, cusolver_dev_13.4,
cusparse_13.4, cusparse_dev_13.4, thrust_13.4, nvtx_13.4,
nvdisasm_13.4, nvprune_13.4, nvfatbin_13.4, cuobjdump_13.4,
cupti_13.4, cuda_profiler_api_13.4, opencl_13.4, sanitizer_13.4

.EXAMPLE
.\install-cuda.ps1 -Admin
.EXAMPLE
.\install-cuda.ps1 -Components nvcc_13.4,cudart_13.4,cublas_13.4
#>

[CmdletBinding()]
param(
  [switch]$Admin,
  [Parameter()][ValidateNotNullOrEmpty()][string]$DownloadURL = "https://developer.download.nvidia.com/compute/cuda/13.4.3/local_installers/cuda_13.4.3_windows_x86_64.exe",
  [Parameter()][string]$InstallRoot = $(if ($env:CUDA_PATH) { $env:CUDA_PATH } else { "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4" }),
  [Parameter()][string[]]$Components = @(
    'nvcc_13.4', 'cudart_13.4', 'nvrtc_13.4', 'nvrtc_dev_13.4', 'nvjitlink_13.4',
    'cublas_13.4', 'cublas_dev_13.4', 'cufft_13.4', 'cufft_dev_13.4',
    'curand_13.4', 'curand_dev_13.4', 'cusolver_13.4', 'cusolver_dev_13.4',
    'cusparse_13.4', 'cusparse_dev_13.4', 'thrust_13.4', 'nvtx_13.4',
    'nvdisasm_13.4', 'nvprune_13.4', 'nvfatbin_13.4', 'cuobjdump_13.4',
    'cupti_13.4', 'cuda_profiler_api_13.4', 'opencl_13.4', 'sanitizer_13.4'
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
$defaultRoot = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4"
$detect = @( $InstallRoot, $defaultRoot, $env:CUDA_PATH ) |
Where-Object { $_ } | Select-Object -Unique |
Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $detect) { throw "[cuda] Install not found. Checked: $InstallRoot, $defaultRoot" }

ChangeEnvironmentVariable -InstallRoot $detect