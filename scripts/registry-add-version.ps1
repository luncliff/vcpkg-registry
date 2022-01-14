using namespace System
using namespace System.IO
param
(
    [String]$Port,
    [String]$VcpkgRoot = $env:VCPKG_ROOT,
    [String]$RegistryRoot = (Join-Path -Path $env:VCPKG_ROOT "vcpkg-registry"),
    [String]$Workspace = (Get-Location)
)

function AddVersion([String]$root, [String]$port) {
    vcpkg.exe version
    vcpkg.exe x-add-version $port `
        --x-builtin-ports-root="$root/ports" `
        --x-builtin-registry-versions-dir="$root/versions"
}

$env:Path = "$VcpkgRoot;$env:Path"
AddVersion $RegistryRoot $Port
