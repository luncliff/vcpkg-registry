<#
.SYNOPSIS
    PowerShell script to help writing 'vcpkg-configuration.json' with this repository
.DESCRIPTION
    Read the template file and print the JSON object

.PARAMETER Dump
    If this switch is provided, 'vcpkg-configuration.json' file will be generated.

.OUTPUTS
    If -Dump is provided

.EXAMPLE
    PS> ./scripts/make-configuration.ps1
#>
# todo: enhance with https://learn.microsoft.com/ko-kr/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters?view=powershell-7.3
param
(
    [String]$Template = "scripts/template.json",
    [String]$Repository = "https://github.com/luncliff/vcpkg-registry",
    [String]$Commit = $(git rev-parse HEAD),
    [switch]$Dump
)
$config = Get-Content $Template -Raw | ConvertFrom-Json;
$packages = $(Get-ChildItem -Path "ports" -Directory).Name

$registry = @{
    "kind"       = "git"
    "repository" = $Repository
    "packages"   = $packages
    "baseline"   = $Commit
}
$config.registries[0] = $registry

if ($Dump) {
    # $output = $registry | ConvertTo-Json
    # Write-Output $output
    $config | ConvertTo-Json -Depth 3 | Out-File -Encoding UTF8 "vcpkg-configuration.json";
}
$output = $registry | ConvertTo-Json -Depth 3
Write-Output $output
