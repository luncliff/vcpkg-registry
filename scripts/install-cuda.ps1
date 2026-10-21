<#
.SYNOPSIS
Install CUDA 12.9, 13.1, or 13.4 silently.

.DESCRIPTION
Checks for the selected CUDA version. If found, exits. Otherwise downloads the CUDA installer,
installs only the requested subpackages in silent mode, and configures env vars.
CUDA 13 defaults to the complete toolkit; CUDA 12 retains the selected CI components.

.PARAMETER Admin
If provided, verify elevation.

.PARAMETER DownloadURL
Optional local installer URL override for the selected CUDA version.

.PARAMETER InstallRoot
Target CUDA root. Defaults to the standard directory for the selected version.

.PARAMETER Components
CUDA subpackages to install. CUDA 13 defaults to all toolkit components.
CUDA 12.9 defaults to a CI set:
nvcc_12.9, cudart_12.9, nvrtc_12.9, nvrtc_dev_12.9, nvjitlink_12.9,
cublas_12.9, cublas_dev_12.9, cufft_12.9, cufft_dev_12.9,
curand_12.9, curand_dev_12.9, cusolver_12.9, cusolver_dev_12.9,
cusparse_12.9, cusparse_dev_12.9, thrust_12.9, nvtx_12.9,
nvdisasm_12.9, nvprune_12.9, nvfatbin_12.9, cuobjdump_12.9,
cupti_12.9, cuda_profiler_api_12.9, opencl_12.9, sanitizer_12.9, nvprof_12.9

.PARAMETER CudaVersion
CUDA toolkit version: 12.9, 13.1, or 13.4. Defaults to 13.4.
An existing CUDA_PATH is reused only when nvcc reports the selected version.

.PARAMETER VerifyDownload
Check the selected artifact with an HTTP HEAD request without installing CUDA.

.EXAMPLE
.\install-cuda.ps1 -Admin
.EXAMPLE
.\install-cuda.ps1 -CudaVersion 12.9 -Components nvcc_12.9,cudart_12.9,cublas_12.9
.EXAMPLE
.\install-cuda.ps1 -CudaVersion 12.9
.EXAMPLE
.\install-cuda.ps1 -CudaVersion 13.1
.EXAMPLE
.\install-cuda.ps1 -CudaVersion 13.4 -VerifyDownload
#>

[CmdletBinding()]
param(
  [switch]$Admin,
  [Parameter()][ValidateNotNullOrEmpty()][string]$DownloadURL,
  [Parameter()][string]$InstallRoot,
  [Parameter()][string[]]$Components,
  [Parameter()][ValidateSet('12.9', '13.1', '13.4')][string]$CudaVersion = '13.4',
  [switch]$VerifyDownload
)

$ErrorActionPreference = 'Stop'
$installers = @{
  '12.9' = '12.9.1/local_installers/cuda_12.9.1_576.57_windows.exe'
  '13.1' = '13.1.2/local_installers/cuda_13.1.2_windows.exe'
  '13.4' = '13.4.3/local_installers/cuda_13.4.3_windows_x86_64.exe'
}
if (-not $PSBoundParameters.ContainsKey('DownloadURL')) {
  $DownloadURL = "https://developer.download.nvidia.com/compute/cuda/$($installers[$CudaVersion])"
}
$defaultRoot = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$CudaVersion"
if (-not $PSBoundParameters.ContainsKey('InstallRoot')) {
  $InstallRoot = $defaultRoot
}
if (-not $PSBoundParameters.ContainsKey('Components') -and $CudaVersion -eq '12.9') {
  $Components = @(
    'nvcc_12.9', 'cudart_12.9', 'nvrtc_12.9', 'nvrtc_dev_12.9', 'nvjitlink_12.9',
    'cublas_12.9', 'cublas_dev_12.9', 'cufft_12.9', 'cufft_dev_12.9',
    'curand_12.9', 'curand_dev_12.9', 'cusolver_12.9', 'cusolver_dev_12.9',
    'cusparse_12.9', 'cusparse_dev_12.9', 'thrust_12.9', 'nvtx_12.9',
    'nvdisasm_12.9', 'nvprune_12.9', 'nvfatbin_12.9', 'cuobjdump_12.9',
    'cupti_12.9', 'cuda_profiler_api_12.9', 'opencl_12.9', 'sanitizer_12.9', 'nvprof_12.9'
  )
}

if ($VerifyDownload) {
  $response = Invoke-WebRequest -Uri $DownloadURL -Method Head -TimeoutSec 60
  if ($response.StatusCode -ne 200) {
    throw "[cuda] Artifact check failed: $DownloadURL (HTTP $($response.StatusCode))"
  }
  Write-Host "[cuda] Verified CUDA $CudaVersion artifact: $DownloadURL"
  return
}

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

function Test-CudaInstallation([string]$Root) {
  if (-not $Root) { return $false }
  $nvcc = Join-Path $Root 'bin\nvcc.exe'
  if (-not (Test-Path -LiteralPath $nvcc)) { return $false }
  $version = & $nvcc --version
  return ($LASTEXITCODE -eq 0 -and ($version -join "`n") -match "release $([regex]::Escape($CudaVersion)),")
}

function ChangeEnvironmentVariable {
  param (
    [string]$InstallRoot
  )
  [Environment]::SetEnvironmentVariable('CUDA_PATH', $InstallRoot, 'Machine')
  Add-PathOnce (Join-Path $InstallRoot 'bin')
  Add-PathOnce (Join-Path $InstallRoot 'bin\x64')
  Add-PathOnce (Join-Path $InstallRoot 'libnvvp')
  Write-Host "[cuda] Using $InstallRoot"
  Write-Output "$InstallRoot"
}
if (Test-CudaInstallation $InstallRoot) {
  ChangeEnvironmentVariable -InstallRoot $InstallRoot
  exit 0
}
if (-not $PSBoundParameters.ContainsKey('InstallRoot') -and (Test-CudaInstallation $env:CUDA_PATH)) {
  ChangeEnvironmentVariable -InstallRoot $env:CUDA_PATH
  exit 0
}

# Download installer
$temp = Join-Path $env:TEMP ("cuda-" + [guid]::NewGuid() + ".exe")
Write-Host "[cuda] Downloading $DownloadURL"
DownloadToFile -Uri $DownloadURL -OutFile $temp

# Silent install with explicit components
# The NVIDIA installer accepts a space-separated list of component names after -s.
# If any component name contains spaces, it must be quoted. We quote each component name to be robust.
$compArgs = $Components | Where-Object { $_ } | ForEach-Object { '"{0}"' -f $_ } | Join-String -Separator " "
$arguments = "-s $compArgs"

Write-Host "[cuda] Installing CUDA $CudaVersion (all toolkit components unless explicitly selected)"
$Components | Where-Object { $_ } | ForEach-Object { Write-Host "  - $_" }

$process = Start-Process -FilePath $temp -ArgumentList $arguments -Wait -NoNewWindow -PassThru
if ($process.ExitCode -notin @(0, 3010)) {
  throw "[cuda] Installer failed with exit code $($process.ExitCode)"
}

# Detect root and persist env
$detect = @( $InstallRoot, $defaultRoot, $env:CUDA_PATH ) |
Where-Object { $_ } | Select-Object -Unique |
Where-Object { Test-CudaInstallation $_ } | Select-Object -First 1
if (-not $detect) { throw "[cuda] Install not found. Checked: $InstallRoot, $defaultRoot" }

ChangeEnvironmentVariable -InstallRoot $detect