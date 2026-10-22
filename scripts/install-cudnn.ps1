<#
.SYNOPSIS
Install cuDNN 9.x for CUDA 12 or CUDA 13 from a ZIP into a chosen root.

.DESCRIPTION
If $env:CUDNN exists and the path is valid, exits.
Otherwise downloads the specified cuDNN redistributable ZIP, extracts the expected
bin/include/lib content into ExtractRoot, sets CUDNN, and adds bin to system PATH.
Only headers, libraries, and runtime DLLs are installed; samples and tools are not copied.
Temporary downloads and extracted contents are removed after installation.

.PARAMETER DownloadURL
cuDNN redistributable ZIP URL for Windows x86_64.
Defaults to 9.27.0.42 for the selected CUDA major version.
An explicit URL overrides CudaVersion.

.PARAMETER ExtractRoot
Target root for cuDNN. Defaults to $env:CUDNN if set, otherwise
"C:\Program Files\NVIDIA\CUDNN\v9.27".

.PARAMETER CudaVersion
CUDA toolkit major version: 12 or 13. Defaults to 13.
NVIDIA provides one cuDNN archive per CUDA major version.
Existing installations are reused regardless of this selection.

.PARAMETER VerifyDownload
Check the selected artifact with an HTTP HEAD request without installing cuDNN.

.EXAMPLE
.\install-cudnn.ps1
.EXAMPLE
.\install-cudnn.ps1 -CudaVersion 12
.EXAMPLE
.\install-cudnn.ps1 -CudaVersion 13
.EXAMPLE
.\install-cudnn.ps1 -DownloadURL "https://.../cudnn-windows-x86_64-9.27.0.42_cuda12-archive.zip"
.EXAMPLE
.\install-cudnn.ps1 -CudaVersion 13 -VerifyDownload
#>

[CmdletBinding()]
param(
  [Parameter()][ValidateNotNullOrEmpty()][string]$DownloadURL,
  [Parameter()][string]$ExtractRoot = $(if ($env:CUDNN) { $env:CUDNN } else { "C:\Program Files\NVIDIA\CUDNN\v9.27" }),
  [Parameter()][ValidateSet('12', '13')][string]$CudaVersion = '13',
  [switch]$VerifyDownload
)

$ErrorActionPreference = 'Stop'

if (-not $PSBoundParameters.ContainsKey('DownloadURL')) {
  $DownloadURL = "https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/windows-x86_64/cudnn-windows-x86_64-9.27.0.42_cuda$CudaVersion-archive.zip"
}

if ($VerifyDownload) {
  $response = Invoke-WebRequest -Uri $DownloadURL -Method Head -TimeoutSec 60
  if ($response.StatusCode -ne 200) {
    throw "[cudnn] Artifact check failed: $DownloadURL (HTTP $($response.StatusCode))"
  }
  Write-Host "[cudnn] Verified cuDNN artifact: $DownloadURL"
  return
}

function Test-CudnnInstallation([string]$Root) {
  if (-not $Root) { return $false }
  $bin = Join-Path $Root 'bin'
  $inc = Join-Path $Root 'include'
  $lib = Join-Path $Root 'lib'
  if (-not (Test-Path -LiteralPath $bin)) { return $false }
  if (-not (Test-Path -LiteralPath $inc)) { return $false }
  if (-not (Test-Path -LiteralPath $lib)) { return $false }
  $dllFound = Get-ChildItem -LiteralPath $bin -Filter 'cudnn*.dll' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  $headerFound = Get-ChildItem -LiteralPath $inc -Filter 'cudnn*.h' -File -ErrorAction SilentlyContinue | Select-Object -First 1
  $libFound = Get-ChildItem -LiteralPath $lib -Filter 'cudnn*.lib' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  return [bool]($dllFound -and $headerFound -and $libFound)
}

if (Test-CudnnInstallation $env:CUDNN) {
  Write-Host "[cudnn] Found at $env:CUDNN";
  Write-Output "$env:CUDNN"
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
    throw "[cudnn] Failed to update machine PATH. Run this script in an Administrator PowerShell."
  }
}

function ChangeEnvironmentVariable {
  param (
    [string]$InstallRoot
  )
  try {
    [Environment]::SetEnvironmentVariable('CUDNN', $InstallRoot, 'Machine')
    [Environment]::SetEnvironmentVariable('CUDNN_ROOT_DIR', $InstallRoot, 'Machine')
  }
  catch {
    throw "[cudnn] Failed to set CUDNN environment variables at machine scope. Run this script in an Administrator PowerShell."
  }
  Add-PathOnce (Join-Path $InstallRoot 'bin')
  Write-Host "[cudnn] Using $InstallRoot"
  Write-Output "$InstallRoot"
}

if (Test-CudnnInstallation $ExtractRoot) {
  ChangeEnvironmentVariable -InstallRoot $ExtractRoot
  exit 0
}

function DownloadToFile([string]$Uri, [string]$OutFile) {
  try {
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -TimeoutSec 600
  }
  catch {
    Write-Error "[cudnn] Download failed: $Uri"
    exit 1
  }
}

$tempZip = Join-Path $env:TEMP ("cudnn-" + [guid]::NewGuid() + '.zip')
$extractTemp = Join-Path $env:TEMP ("cudnn-extract-" + [guid]::NewGuid())
try {
  Write-Host "[cudnn] Downloading $DownloadURL"
  DownloadToFile -Uri $DownloadURL -OutFile $tempZip

  Expand-Archive -Path $tempZip -DestinationPath $extractTemp -Force
  $pkg = Get-ChildItem -Directory $extractTemp | Select-Object -First 1
  if (-not $pkg) { throw '[cudnn] Unexpected archive layout.' }

  $bin = Join-Path $pkg.FullName 'bin'
  $inc = Join-Path $pkg.FullName 'include'
  $lib = Join-Path $pkg.FullName 'lib'

  New-Item -ItemType Directory -Force -Path (Join-Path $ExtractRoot 'bin') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $ExtractRoot 'include') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $ExtractRoot 'lib') | Out-Null

  $dllFiles = Get-ChildItem -Path $bin -Filter 'cudnn*.dll' -File -Recurse -ErrorAction SilentlyContinue
  if (-not $dllFiles) {
    Write-Error "[cudnn] No cuDNN DLLs found in $bin"
    exit 1
  }
  Copy-Item -Path $dllFiles.FullName -Destination (Join-Path $ExtractRoot 'bin') -Force

  $headerFiles = Get-ChildItem -Path (Join-Path $inc 'cudnn*.h') -ErrorAction SilentlyContinue
  if (-not $headerFiles) {
    Write-Error "[cudnn] No cuDNN headers found in $inc"
    exit 1
  }
  Copy-Item -Path $headerFiles.FullName -Destination (Join-Path $ExtractRoot 'include') -Force

  $libFiles = Get-ChildItem -Path $lib -Filter 'cudnn*.lib' -File -Recurse -ErrorAction SilentlyContinue
  if (-not $libFiles) {
    Write-Error "[cudnn] No cuDNN libraries found in $lib"
    exit 1
  }
  Copy-Item -Path $libFiles.FullName -Destination (Join-Path $ExtractRoot 'lib') -Force
  Set-Content -LiteralPath (Join-Path $ExtractRoot '.vcpkg-cudnn-install') -Value 'cuDNN archive installation'
  ChangeEnvironmentVariable -InstallRoot $ExtractRoot
}
finally {
  foreach ($path in @($tempZip, $extractTemp)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
  }
}
