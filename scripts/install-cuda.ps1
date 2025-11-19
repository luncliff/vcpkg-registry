<#
.SYNOPSIS
Install CUDA 12.9.x silently with selected components.

.DESCRIPTION
Checks $env:CUDA_PATH. If valid, exits. Otherwise downloads the CUDA installer,
installs only the requested subpackages in silent mode, and configures env vars.
Defaults now include profiler/debug components for CI.

.PARAMETER Admin
If provided, verify elevation.

.PARAMETER DownloadURL
CUDA 12.9.x local installer URL. Defaults to NVIDIA 12.9.1 full installer.

.PARAMETER InstallRoot
Target CUDA root. Defaults to $env:CUDA_PATH or the standard v12.9 path.

.PARAMETER Components
CUDA subpackages to install. Defaults to a CI set:
nvcc_12.9, cudart_12.9, nvrtc_12.9, nvrtc_dev_12.9, nvjitlink_12.9,
cublas_12.9, cublas_dev_12.9, cufft_12.9, cufft_dev_12.9,
curand_12.9, curand_dev_12.9, cusolver_12.9, cusolver_dev_12.9,
cusparse_12.9, cusparse_dev_12.9, thrust_12.9, nvtx_12.9,
nvdisasm_12.9, nvprune_12.9, nvfatbin_12.9, cuobjdump_12.9,
cupti_12.9, cuda_profiler_api_12.9, opencl_12.9, sanitizer_12.9, nvprof_12.9

.EXAMPLE
.\install-cuda.ps1 -Admin
.EXAMPLE
.\install-cuda.ps1 -Components nvcc_12.9,cudart_12.9,cublas_12.9
#>

[CmdletBinding()]
param(
  [switch]$Admin,
  [Parameter()][ValidateNotNullOrEmpty()][string]$DownloadURL = "https://developer.download.nvidia.com/compute/cuda/12.9.1/local_installers/cuda_12.9.1_576.57_windows.exe",
  [Parameter()][string]$InstallRoot = $(if ($env:CUDA_PATH) { $env:CUDA_PATH } else { "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9" }),
  [Parameter()][string[]]$Components = @(
    'nvcc_12.9', 'cudart_12.9', 'nvrtc_12.9', 'nvrtc_dev_12.9', 'nvjitlink_12.9',
    'cublas_12.9', 'cublas_dev_12.9', 'cufft_12.9', 'cufft_dev_12.9',
    'curand_12.9', 'curand_dev_12.9', 'cusolver_12.9', 'cusolver_dev_12.9',
    'cusparse_12.9', 'cusparse_dev_12.9', 'thrust_12.9', 'nvtx_12.9',
    'nvdisasm_12.9', 'nvprune_12.9', 'nvfatbin_12.9', 'cuobjdump_12.9',
    'cupti_12.9', 'cuda_profiler_api_12.9', 'opencl_12.9', 'sanitizer_12.9', 'nvprof_12.9'
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
$compArgs = $Components -join ' '
$arguments = "-s -n $compArgs"

Write-Host "[cuda] Installing selected components:"
$Components | ForEach-Object { Write-Host "  - $_" }

Start-Process -FilePath $temp -ArgumentList $arguments -Wait -NoNewWindow

# Detect root and persist env
$defaultRoot = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9"
$detect = @( $InstallRoot, $defaultRoot, $env:CUDA_PATH ) |
Where-Object { $_ } | Select-Object -Unique |
Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $detect) { throw "[cuda] Install not found. Checked: $InstallRoot, $defaultRoot" }

ChangeEnvironmentVariable -InstallRoot $detect