<#
.SYNOPSIS
    PowerShell script to change `SHA512` string in the portfile.cmake
.DESCRIPTION
    Run `vcpkg install` with the given vcpkg port, then change the `SHA512` in the portfile.cmake to the 

.PARAMETER PortName
    The name of the port to try `vcpkg install` command
.PARAMETER PortsDirectory
    The path for `--overlay-ports` option of the `vcpkg install` command
.PARAMETER LogFile
    The path to store the output of the `vcpkg install` command

.OUTPUTS
    "${PortName} ${ActualHash}"

.EXAMPLE
    PS> update-portfile-sha512.ps1 -PortName abseil -PortsDirectory ports -LogFile install.log
    abseil ${ActualHash}
.EXAMPLE
    PS> update-portfile-sha512.ps1 -PortName eigen3 -PortsDirectory "$(Get-Location)/ports" -LogFile install.log
    eigen3 ${ActualHash}
#>
param (
    [Parameter(Mandatory = $true)][string]$PortName,
    [Parameter(Mandatory = $true)][string]$PortsDirectory,
    [string]$PortFile = "$PortsDirectory/$PortName/portfile.cmake",
    [Parameter(Mandatory = $true)][string]$LogFile
)

# Check if the PortFile exists
if (-Not (Test-Path -Path $PortFile)) {
    Write-Error "'$PortFile' does not exist."
    exit 1
}

function ChangeSHA512 {
    param (
        [Parameter(Mandatory = $true)][string]$PortFile,
        [string]$ReplacedHash = "0"
    )
    $Content = Get-Content -Path $PortFile
    $Pattern = 'SHA512\s+[a-fA-F0-9]+'
    $Replacement = "SHA512 $ReplacedHash"
    $UpdatedContent = $Content -replace $Pattern, $Replacement
    Set-Content -Path $PortFile -Value $UpdatedContent
}

function TryVcpkgInstall {
    param (
        [Parameter(Mandatory = $true)][string]$PortName,
        [Parameter(Mandatory = $true)][string]$PortsDirectory,
        [Parameter(Mandatory = $true)][string]$LogFile
    )
    try {
        $InstallExpression = "vcpkg install --overlay-ports ${PortsDirectory} --editable ${PortName}"
        $InstallOutput = Invoke-Expression $InstallExpression
        Set-Content -Path $LogFile -Value $InstallOutput
    } catch {
        Write-Error "$_"
        exit 1
    }
}

function FindActualHash {
    param (
        [Parameter(Mandatory = $true)][string]$LogFile
    )
    $LogContent = Get-Content -Path $LogFile
    $ActualHashPattern = 'Actual hash:\s+([a-fA-F0-9]+)'
    [string]$MatchedLine = $LogContent -match $ActualHashPattern
    # If failed to find actual hash, return empty string
    if (-Not $MatchedLine) {
        return ""
    }
    [string]$ActualHash = $MatchedLine.Substring(13)
    return $ActualHash
}

# Step 1: Change the SHA512 value in the portfile.cmake to 0
ChangeSHA512 -PortFile $PortFile -ReplacedHash "0"

# Step 2: Run the vcpkg install command for the changed port and capture the output
TryVcpkgInstall -PortName $PortName -PortsDirectory $PortsDirectory -LogFile $LogFile

# Step 3: Parse the failure log to extract the Actual hash
[string]$ActualHash = FindActualHash -LogFile $LogFile
if (-Not $ActualHash) {
    Write-Error "Failed to detect the actual SHA512 hash."
    exit 1
}

# Step4: Change the SHA512 value in the portfile.cmake to the actual hash
ChangeSHA512 -PortFile $PortFile -ReplacedHash $ActualHash

Write-Output "$PortName $ActualHash"
