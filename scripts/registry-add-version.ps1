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
    ./vcpkg version
    ./vcpkg x-add-version $port `
        --x-builtin-ports-root="$root/ports" `
        --x-builtin-registry-versions-dir="$root/versions"
}

# $env:Path = "$VcpkgRoot;$env:Path"
Push-Location $VcpkgRoot
    AddVersion $RegistryRoot $Port
Pop-Location
