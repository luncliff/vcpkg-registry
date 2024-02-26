<#
.SYNOPSIS
    PowerShell script to modify JSON files under the registry's 'versions' folder
.DESCRIPTION
    Runs vcpkg executable and update baseline/version JSON files.

.EXAMPLE
    PS> registry-add-version.ps1 -PortNmae "openssl" -VcpkgRoot $env:VCPKG_ROOT 
.EXAMPLE
    PS> registry-add-version.ps1 "openssl" -VcpkgRoot $env:VCPKG_ROOT 
    version 1.1.1t is already in C:\vcpkg\vcpkg-registry\versions\o-\openssl1.json
    version 1.1.1t is already in C:\vcpkg\vcpkg-registry\versions\baseline.json
    No files were updated for openssl1
#>
using namespace System
param
(
    [Parameter(Position = 0, Mandatory = $true)][String]$PortName,
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

function RunAddVersion([String]$PortName, [String]$PortRoot, [String]$VersionRoot) {
    vcpkg x-add-version $PortName `
        --overwrite-version `
        --vcpkg-root="$VcpkgRoot" `
        --x-builtin-ports-root="$PortRoot" `
        --x-builtin-registry-versions-dir="$VersionRoot"
}

RunAddVersion -PortName $PortName -PortRoot $(Join-Path $RegistryRoot "ports") -VersionRoot $(Join-Path $RegistryRoot "versions")
