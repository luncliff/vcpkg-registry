<#
.SYNOPSIS
Install CUDA 12 or CUDA 13 silently with selected components.

.DESCRIPTION
Checks for the selected CUDA release. If found, exits. Otherwise downloads the CUDA installer,
installs only the requested subpackages in silent mode, and configures env vars.
CUDA 12 maps to 12.9 and CUDA 13 maps to 13.4. The version-specific component defaults
remain aligned with the registry's CUDA 12.9 and 13.4 configurations.

.PARAMETER Admin
If provided, verify elevation.

.PARAMETER DownloadURL
Optional local installer URL override for the selected CUDA major version.

.PARAMETER InstallRoot
Target CUDA root. Defaults to the standard directory for the selected CUDA release.

.PARAMETER Components
CUDA subpackages to install. Defaults to the version-specific CI component set.
Empty lists are rejected; full-toolkit installation is never used.

.PARAMETER CudaVersion
CUDA toolkit major version: 12 or 13. Defaults to 13.

.PARAMETER VerifyDownload
Check the selected artifact with an HTTP HEAD request without installing CUDA.

.EXAMPLE
.\install-cuda.ps1 -Admin
.EXAMPLE
.\install-cuda.ps1 -CudaVersion 12 -Components nvcc_12.9,cudart_12.9,cublas_12.9
.EXAMPLE
.\install-cuda.ps1 -CudaVersion 13
.EXAMPLE
.\install-cuda.ps1 -CudaVersion 13 -VerifyDownload
#>

[CmdletBinding()]
param(
  [switch]$Admin,
  [Parameter()][ValidateNotNullOrEmpty()][string]$DownloadURL,
  [Parameter()][string]$InstallRoot,
  [Parameter()][string[]]$Components,
  [Parameter()][ValidateSet('12', '13')][string]$CudaVersion = '13',
  [switch]$VerifyDownload
)

$ErrorActionPreference = 'Stop'
$cudaReleases = @{
  '12' = '12.9'
  '13' = '13.4'
}
$installers = @{
  '12' = '12.9.1/local_installers/cuda_12.9.1_576.57_windows.exe'
  '13' = '13.4.3/local_installers/cuda_13.4.3_windows_x86_64.exe'
}
$componentsByCudaVersion = @{
  '12' = @(
    'nvcc_12.9', 'cudart_12.9', 'nvrtc_12.9', 'nvrtc_dev_12.9', 'nvjitlink_12.9',
    'cublas_12.9', 'cublas_dev_12.9', 'cufft_12.9', 'cufft_dev_12.9',
    'curand_12.9', 'curand_dev_12.9', 'cusolver_12.9', 'cusolver_dev_12.9',
    'cusparse_12.9', 'cusparse_dev_12.9', 'thrust_12.9', 'nvtx_12.9',
    'nvdisasm_12.9', 'nvprune_12.9', 'nvfatbin_12.9', 'cuobjdump_12.9',
    'cupti_12.9', 'cuda_profiler_api_12.9', 'opencl_12.9', 'sanitizer_12.9', 'nvprof_12.9'
  )
  '13' = @(
    'nvcc_13.4', 'cudart_13.4', 'nvrtc_13.4', 'nvrtc_dev_13.4', 'nvjitlink_13.4',
    'cublas_13.4', 'cublas_dev_13.4', 'cufft_13.4', 'cufft_dev_13.4',
    'curand_13.4', 'curand_dev_13.4', 'cusolver_13.4', 'cusolver_dev_13.4',
    'cusparse_13.4', 'cusparse_dev_13.4', 'thrust_13.4', 'nvtx_13.4',
    'nvdisasm_13.4', 'nvprune_13.4', 'nvfatbin_13.4', 'cuobjdump_13.4',
    'cupti_13.4', 'cuda_profiler_api_13.4', 'opencl_13.4', 'sanitizer_13.4'
  )
}
$cudaRelease = $cudaReleases[$CudaVersion]
if (-not $PSBoundParameters.ContainsKey('DownloadURL')) {
  $DownloadURL = "https://developer.download.nvidia.com/compute/cuda/$($installers[$CudaVersion])"
}
$defaultRoot = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$cudaRelease"
if (-not $PSBoundParameters.ContainsKey('InstallRoot')) {
  $InstallRoot = $defaultRoot
}
if (-not $PSBoundParameters.ContainsKey('Components')) {
  $Components = $componentsByCudaVersion[$CudaVersion]
}
$Components = @($Components | Where-Object { $_ })
if (-not $Components.Count) {
  throw '[cuda] Components must contain at least one package.'
}

if ($VerifyDownload) {
  $response = Invoke-WebRequest -Uri $DownloadURL -Method Head -TimeoutSec 60
  if ($response.StatusCode -ne 200) {
    throw "[cuda] Artifact check failed: $DownloadURL (HTTP $($response.StatusCode))"
  }
  Write-Host "[cuda] Verified CUDA $cudaRelease artifact: $DownloadURL"
  return
}

function EnsureAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = [Security.Principal.WindowsPrincipal]::new($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    throw 'Must run elevated. Re-run in an Administrator PowerShell.'
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
  return ($LASTEXITCODE -eq 0 -and ($version -join "`n") -match "release $([regex]::Escape($cudaRelease)),")
}

function ChangeEnvironmentVariable {
  param (
    [string]$InstallRoot
  )
  [Environment]::SetEnvironmentVariable('CUDA_PATH', $InstallRoot, 'Machine')
  Add-PathOnce (Join-Path $InstallRoot 'bin')
  Add-PathOnce (Join-Path $InstallRoot 'bin\x64')
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

$temp = Join-Path $env:TEMP ("cuda-" + [guid]::NewGuid() + '.exe')
try {
  Write-Host "[cuda] Downloading $DownloadURL"
  DownloadToFile -Uri $DownloadURL -OutFile $temp

  $compArgs = $Components | ForEach-Object { '"{0}"' -f $_ } | Join-String -Separator ' '
  $arguments = "-s $compArgs"

  Write-Host "[cuda] Installing CUDA $cudaRelease selected components"
  $Components | ForEach-Object { Write-Host "  - $_" }

  $process = Start-Process -FilePath $temp -ArgumentList $arguments -Wait -NoNewWindow -PassThru
  if ($process.ExitCode -notin @(0, 3010)) {
    throw "[cuda] Installer failed with exit code $($process.ExitCode)"
  }

  $detect = @( $InstallRoot, $defaultRoot, $env:CUDA_PATH ) |
  Where-Object { $_ } | Select-Object -Unique |
  Where-Object { Test-CudaInstallation $_ } | Select-Object -First 1
  if (-not $detect) { throw "[cuda] Install not found. Checked: $InstallRoot, $defaultRoot" }

  ChangeEnvironmentVariable -InstallRoot $detect
}
finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
}
