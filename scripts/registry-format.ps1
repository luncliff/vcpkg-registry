using namespace System
using namespace System.IO
param
(
    [String]$VcpkgRoot = $env:VCPKG_ROOT,
    [String]$RegistryRoot = (Join-Path -Path $env:VCPKG_ROOT "vcpkg-registry"),
    [String]$Workspace = (Get-Location)
)

function RunFormat($root) {
    vcpkg.exe version
    vcpkg.exe format-manifest --all --vcpkg-root=$root
    # --x-builtin-ports-root="$root/ports" `
    # --x-builtin-registry-versions-dir="$root/versaions"
}

$env:Path = "$VcpkgRoot;$env:Path"
RunFormat($RegistryRoot)
