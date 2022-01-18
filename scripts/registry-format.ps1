using namespace System
using namespace System.IO
param
(
    [String]$VcpkgRoot = $env:VCPKG_ROOT,
    [String]$RegistryRoot = (Join-Path -Path $env:VCPKG_ROOT "vcpkg-registry"),
    [String]$Workspace = (Get-Location)
)

function RunFormat($root) {
    ./vcpkg version
    ./vcpkg format-manifest --all `
        --x-builtin-ports-root="$root/ports" `
        --x-builtin-registry-versions-dir="$root/versions"
}

# $env:Path = "$VcpkgRoot;$env:Path"
Push-Location $VcpkgRoot
    RunFormat $RegistryRoot
Pop-Location
