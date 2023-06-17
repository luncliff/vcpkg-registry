<#
.SYNOPSIS
    PowerShell script to lint vcpkg.json under the registry's 'ports' folder
.DESCRIPTION
    Runs vcpkg executable and manipulates existing vcpkg.json files.

.LINK
    https://github.com/microsoft/vcpkg
    https://github.com/microsoft/vcpkg-tool/blob/2023-06-15/include/vcpkg/vcpkgcmdarguments.h

.PARAMETER VcpkgRoot
    The root folder to find vcpkg.exe program
.PARAMETER RegistryRoot
    Root folder of the vcpkg registry.
    If not provided, use "${VcpkgRoot}/vcpkg-registry"

.EXAMPLE
    PS> registry-format.ps1 -VcpkgRoot $env:VCPKG_ROOT
    Succeeded in formatting the manifest files.
.EXAMPLE
    PS> registry-format.ps1 -VcpkgRoot "D:/vcpkg" -RegistryRoot $(Get-Location)
    Succeeded in formatting the manifest files.
.EXAMPLE
    PS> registry-format.ps1 -VcpkgRoot $env:VCPKG_ROOT -RegistryRoot "D:/test-registry"
    Line |
      46 |      throw New-Object -TypeName ArgumentException "RegistryRoot doesn' …
         |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
         | RegistryRoot doesn't exist
#>
using namespace System
param
(
    [Parameter(Mandatory = $true)][String]$VcpkgRoot,
    [String]$RegistryRoot
)

# VcpkgRoot
[Boolean]$RootExists = $(Test-Path -Path $VcpkgRoot)
if ($RootExists -eq $false) {
    throw New-Object -TypeName ArgumentException "VcpkgRoot doesn't exist"
}
${env:Path} = "$VcpkgRoot;${env:Path}"

# RegistryRoot
if ($RegistryRoot.Length -eq 0) {
    $RegistryRoot = (Join-Path -Path $VcpkgRoot "vcpkg-registry")
    Write-Debug "RegistryRoot=${RegistryRoot}"
}
[Boolean]$RegistryExists = $(Test-Path -Path $RegistryRoot)
if ($RegistryExists -eq $false) {
    throw New-Object -TypeName ArgumentException "RegistryRoot doesn't exist"
}

function RunVersion() {
    [String]$Description = $(vcpkg version)
    Write-Debug -Message $Description
}

function RunConvert([String]$PortRoot) {
    vcpkg format-manifest --all --convert-control `
        --vcpkg-root="$VcpkgRoot" `
        --x-builtin-ports-root="$PortRoot"
}

function RunFormat([String]$PortRoot, [String]$VersionRoot) {
    Write-Debug "PortRoot=${PortRoot}"
    Write-Debug "VersionRoot=${VersionRoot}"
    vcpkg format-manifest --all `
        --vcpkg-root="$VcpkgRoot" `
        --x-builtin-ports-root="$PortRoot" `
        --x-builtin-registry-versions-dir="$VersionRoot"
}

RunVersion
# RunConvert -PortRoot $(Join-Path $RegistryRoot "ports") 
RunFormat -PortRoot $(Join-Path $RegistryRoot "ports") -VersionRoot $(Join-Path $RegistryRoot "versions")
