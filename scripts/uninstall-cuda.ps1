<#
.SYNOPSIS
List or uninstall selected Windows CUDA and cuDNN versions.

.DESCRIPTION
Without version selectors, lists visible registered CUDA/cuDNN packages and toolkit directories.
-DryRun always lists matching installations without changing files, registry, or environment.
Registered packages use MSI product codes or validated NVIDIA Installer2 uninstall commands.
Uninstall strings are never evaluated as PowerShell. NVIDIA uninstallers may show their own UI.
Only cuDNN ZIP installations with the installer ownership marker, or version directories
under the standard NVIDIA cuDNN root without a registered package, are removed directly.
CUDA directories without a registered uninstaller are listed but never recursively deleted.
NVIDIA drivers, Nsight, and other shared software are not selected.
Run elevated for removal. Restart shells after environment cleanup.

.PARAMETER CudaVersion
CUDA major.minor versions to remove, such as 12.9 or 13.4.

.PARAMETER CudnnVersion
cuDNN major.minor versions to remove, such as 9.27.
All CUDA variants of that cuDNN version are selected.

.PARAMETER DryRun
List selected installations only. Also available through the standard -WhatIf switch.

.EXAMPLE
.\uninstall-cuda.ps1 -DryRun
.EXAMPLE
.\uninstall-cuda.ps1 -CudaVersion 12.9 -CudnnVersion 9.27 -WhatIf
.EXAMPLE
.\uninstall-cuda.ps1 -CudaVersion 13.4
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
  [ValidatePattern('^[0-9]+\.[0-9]+$')][string[]]$CudaVersion,
  [ValidatePattern('^[0-9]+\.[0-9]+$')][string[]]$CudnnVersion,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This helper requires Windows.' }

$installations = @()
$registryRoots = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
)
foreach ($registryRoot in $registryRoots) {
  foreach ($entry in Get-ItemProperty "$registryRoot\*" -ErrorAction SilentlyContinue) {
    if ($entry.Publisher -notmatch '^NVIDIA' -or $entry.DisplayName -notmatch '^(?:NVIDIA )?(CUDA|cuDNN)\b') {
      continue
    }
    $kind = if ($entry.DisplayName -match '\bcuDNN\b') { 'CUDNN' } else { 'CUDA' }
    $versionText = if ($entry.DisplayName -match '([0-9]+\.[0-9]+)') { $Matches[1] } else { $entry.DisplayVersion }
    if ($versionText -notmatch '^([0-9]+\.[0-9]+)') { continue }
    $version = $Matches[1]
    $productCode = $null
    $command = $null
    $arguments = $null
    if ($entry.UninstallString -match '(?i)^\s*"?(?:[^"]*\\)?msiexec(?:\.exe)?"?\s+/[IX]\s*(\{[0-9A-F-]{36}\})') {
      $productCode = $Matches[1]
    }
    elseif ($entry.UninstallString -match '(?i)^"?(?<exe>[^"]*\\rundll32\.exe)"?\s+"(?<dll>[^"]+\\NVI2\.DLL)",UninstallPackage\s+(?<package>(?:CUDA|cuDNN)[A-Za-z0-9_.-]+)\s*$') {
      $exe = $Matches['exe']
      $dll = $Matches['dll']
      $package = $Matches['package']
      if ($exe -in @("$env:SystemRoot\System32\rundll32.exe", "$env:SystemRoot\SysWOW64\rundll32.exe") -and
          $dll -eq "$env:ProgramFiles\NVIDIA Corporation\Installer2\InstallerCore\NVI2.DLL" -and
          $package.EndsWith("_$version", [StringComparison]::OrdinalIgnoreCase)) {
        $command = $exe
        $arguments = "`"$dll`",UninstallPackage $package"
      }
    }
    $installations += [pscustomobject]@{
      Kind = $kind; Version = $version; Name = $entry.DisplayName
      Path = $entry.InstallLocation; ProductCode = $productCode; Method = 'Registered'
      Command = $command; Arguments = $arguments
    }
  }
}

$directories = @()
foreach ($base in @(
  "$env:ProgramFiles\NVIDIA GPU Computing Toolkit\CUDA",
  "$env:ProgramFiles\NVIDIA\CUDNN"
)) {
  $directories += @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue)
}
foreach ($root in @($env:CUDA_PATH, $env:CUDNN, $env:CUDNN_ROOT_DIR) | Where-Object { $_ } | Select-Object -Unique) {
  if (Test-Path -LiteralPath $root -PathType Container) { $directories += Get-Item -LiteralPath $root }
}
foreach ($directory in $directories | Sort-Object FullName -Unique) {
  if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
  $kind = $null
  $version = $null
  if (Test-Path -LiteralPath (Join-Path $directory.FullName 'bin\nvcc.exe')) {
    if ($directory.Name -match '^v([0-9]+\.[0-9]+)$') {
      $kind = 'CUDA'; $version = $Matches[1]
    }
  } elseif (Test-Path -LiteralPath (Join-Path $directory.FullName 'include\cudnn_version.h')) {
    $header = Get-Content -LiteralPath (Join-Path $directory.FullName 'include\cudnn_version.h') -Raw
    if ($header -match '#define\s+CUDNN_MAJOR\s+([0-9]+)') {
      $major = $Matches[1]
      if ($header -match '#define\s+CUDNN_MINOR\s+([0-9]+)') {
        $kind = 'CUDNN'; $version = "$major.$($Matches[1])"
      }
    }
  }
  if (-not $kind) { continue }
  $method = 'DirectoryOnly'
  $registered = @($installations | Where-Object { $_.Kind -eq $kind -and $_.Version -eq $version })
  $standardArchive = $directory.Parent.FullName -eq "$env:ProgramFiles\NVIDIA\CUDNN" -and
    $directory.Name -match '^v[0-9]+\.[0-9]+(?:-cuda(?:12|13))?$' -and -not $registered.Count
  if ($kind -eq 'CUDNN' -and ($standardArchive -or
      (Test-Path -LiteralPath (Join-Path $directory.FullName '.vcpkg-cudnn-install')))) {
    $method = 'Archive'
  }
  $installations += [pscustomobject]@{
    Kind = $kind; Version = $version; Name = $directory.Name
    Path = $directory.FullName; ProductCode = $null; Method = $method
  }
}

$selected = @($installations | Where-Object {
  if (-not $CudaVersion -and -not $CudnnVersion) { $true }
  elseif ($_.Kind -eq 'CUDA') { $_.Version -in $CudaVersion }
  else { $_.Version -in $CudnnVersion }
})
$selected | Select-Object Kind, Version, Name, Path, Method
if ($DryRun -or (-not $CudaVersion -and -not $CudnnVersion)) { return }

$completedCommands = @{}
foreach ($installation in $selected) {
  if ($installation.Method -eq 'DirectoryOnly') {
    Write-Warning "Not deleting unmanaged directory: $($installation.Path). Use its original installer to remove it."
    continue
  }
  if ($installation.Method -eq 'Registered' -and -not $installation.ProductCode -and -not $installation.Command) {
    Write-Warning "No supported uninstaller for $($installation.Name); use Windows Installed Apps."
    continue
  }
  $target = "$($installation.Kind) $($installation.Version): $($installation.Name) $($installation.Path)"
  if (-not $PSCmdlet.ShouldProcess($target, 'Uninstall')) { continue }
  if ($installation.Method -eq 'Registered') {
    $command = "$env:SystemRoot\System32\msiexec.exe"
    $arguments = "/x $($installation.ProductCode) /qn /norestart"
    if ($installation.Command) {
      $command = $installation.Command
      $arguments = $installation.Arguments
    }
    $key = "$command $arguments"
    if ($completedCommands.ContainsKey($key)) { continue }
    $process = Start-Process -FilePath $command -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -notin @(0, 1605, 3010)) {
      throw "Uninstall failed for $target (exit code $($process.ExitCode))"
    }
    $completedCommands[$key] = $true
    continue
  }
  $root = [IO.Path]::GetFullPath($installation.Path).TrimEnd('\')
  if ($root -eq [IO.Path]::GetPathRoot($root).TrimEnd('\') -or $root -eq $env:ProgramFiles -or $root -eq $env:SystemRoot) {
    throw "Refusing unsafe removal path: $root"
  }
  if (Get-ChildItem -LiteralPath $root -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) {
    throw "Refusing removal of installation containing reparse points: $root"
  }
  Remove-Item -LiteralPath $root -Recurse -Force
  foreach ($scope in @('Process', 'User', 'Machine')) {
    foreach ($name in @('CUDNN', 'CUDNN_ROOT_DIR')) {
      $value = [Environment]::GetEnvironmentVariable($name, $scope)
      if ($value -and $value.TrimEnd('\') -eq $root) {
        [Environment]::SetEnvironmentVariable($name, $null, $scope)
      }
    }
    $path = [Environment]::GetEnvironmentVariable('Path', $scope)
    if ($path) {
      $remaining = $path -split ';' | Where-Object {
        $_.TrimEnd('\') -ne $root -and -not $_.StartsWith("$root\", [StringComparison]::OrdinalIgnoreCase)
      }
      [Environment]::SetEnvironmentVariable('Path', ($remaining -join ';'), $scope)
    }
  }
}
