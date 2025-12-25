---
layout: base.njk
title: Guide - Update Version Baseline
---

# Guide: Update Version Baseline

This document covers version management, SHA512 calculation, and registry version tracking for port updates. It complements the main [update port guide](./guide-update-port.md).

## 1. Version Field Types

vcpkg supports different version field types in `vcpkg.json`. Choose the appropriate type based on upstream versioning:

### Semantic Versioning (`version`)
Use for standard semantic versions (MAJOR.MINOR.PATCH):
```json
{
  "name": "port-name",
  "version": "2.1.3"
}
```

### String Versions (`version-string`)
Use for non-semantic version strings:
```json
{
  "name": "port-name", 
  "version-string": "2021-03-15"
}
```

### Strict Semantic Versioning (`version-semver`)
Use when strict semantic version compliance is required:
```json
{
  "name": "port-name",
  "version-semver": "1.2.3-alpha.1"
}
```

### Date Versions (`version-date`)
Use for date-based versioning:
```json
{
  "name": "port-name",
  "version-date": "2024-03-15"
}
```

## 2. SHA512 Hash Calculation

The SHA512 hash ensures download integrity and reproducible builds.

### Method 1: Using vcpkg Error Report

1. **Set SHA512 to `0` temporarily:**
```cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO owner/repo
    REF v2.1.3
    SHA512 0  # Temporary value
    HEAD_REF main
)
```

2. **Run vcpkg install to get the correct hash:**
```powershell
vcpkg install --overlay-ports=ports port-name
```

3. **Extract SHA512 from error message:**
```
Expected hash: 1234567890abcdef...
Actual hash:   fedcba0987654321...
```

4. **Update portfile with the reported hash**

### Method 2: Manual Calculation

```powershell
# PowerShell method
$Version = "2.1.3"
$Url = "https://github.com/owner/repo/archive/v$Version.tar.gz"

# Download the archive
curl -L -o "temp-$Version.tar.gz" $Url

# Calculate SHA512 (ensure lowercase for vcpkg)
$Hash = (Get-FileHash -Algorithm SHA512 "temp-$Version.tar.gz").Hash.ToLower()
Write-Host "SHA512: $Hash"

# Clean up
Remove-Item "temp-$Version.tar.gz"
```

### Method 3: Using Registry Script

If available in your registry:
```powershell
./scripts/update-portfile-sha512.ps1 -PortName "port-name" -NewVersion "2.1.3"
```

## 3. Registry Version Tracking

The registry maintains version information in two places:

### Baseline File (`versions/baseline.json`)
Contains the current version of each port:
```json
{
  "default": {
    "port-name": {
      "baseline": "2.1.3",
      "port-version": 0
    }
  }
}
```

### Port Version History (`versions/p-/port-name.json`)
Contains the complete version history:
```json
{
  "versions": [
    {
      "version": "2.1.3",
      "port-version": 0,
      "git-tree": "abcd1234..."
    },
    {
      "version": "2.1.2", 
      "port-version": 0,
      "git-tree": "efgh5678..."
    }
  ]
}
```

## 4. Version Update Workflow

Here, we assume `<port-name>` is a name of the port being updated.

### Step 1: Update Port Version

Update the version in `vcpkg.json`:
```json
{
  "name": "<port-name>",
  "version": "3.1.4",
  "description": "...",
  "homepage": "...",
  "license": null
}
```

### Step 2: Update Source Reference

Update `REF` and calculate new `SHA512` in `portfile.cmake`:
```cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO "${org}/${repo}"
    REF ${repo-git-release-or-tag}
    SHA512 a1b2c3d4e5f6...  # New hash
    HEAD_REF master
)
```

### Step 3: Test the Update

```powershell
# Clean test installation
vcpkg remove <port-name>
vcpkg install --overlay-ports=ports <port-name>
```

### Step 4: Format Port Files

```powershell
./scripts/registry-format.ps1 -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
```

### Step 5: Commit Port Changes

**CRITICAL:** Always commit port changes before running version registration:
```powershell
git add ./ports/<port-name>/
git commit -m "[<port-name>] update to v3.1.4" -m "- https://github.com/<org>/<repo>/releases/tag/<release-name>"
```

### Step 6: Register New Version

```powershell
./scripts/registry-add-version.ps1 -PortName "<port-name>" -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
```

### Step 7: Commit Version Files

```powershell
git add ./versions/
git commit -m "[<port-name>] update baseline and version files for v3.1.4"
```

## 5. Version Management Best Practices

### Git State Requirements
- **Fresh git state required:** The registry scripts require a clean git repository state
- **Commit before version registration:** Always commit port changes before running `registry-add-version.ps1`
- **Separate commits:** Keep port changes and version registration in separate commits

### Version Selection Guidelines
- **Follow upstream:** Use the same versioning scheme as upstream when possible
- **Consistency:** Be consistent within a port family (e.g., all openssl ports)
- **Clarity:** Choose the most descriptive version type for users

### Hash Verification
- **Always verify:** Never commit without verifying the SHA512 hash
- **Use lowercase:** vcpkg expects lowercase hash values
- **Test download:** Ensure the URL is accessible and stable

## 6. Common Version Scenarios

### Standard Release Update
```json
// Before
{ "version": "1.2.3" }

// After  
{ "version": "1.2.4" }
```

### Pre-release to Release
```json
// Before
{ "version-string": "1.3.0-rc1" }

// After
{ "version": "1.3.0" }
```

### Date-based Versioning
```json
// Before
{ "version-date": "2024-01-15" }

// After
{ "version-date": "2024-03-15" }
```

### Port Version Increment
When the vcpkg port changes but upstream version stays the same:
```json
{
  "version": "1.2.3",
  "port-version": 1  // Increment this
}
```

## 7. SHA512 Troubleshooting

### Common Issues

#### Wrong Hash Format
```cmake
# Wrong - uppercase
SHA512 ABC123DEF456...

# Correct - lowercase  
SHA512 abc123def456...
```

#### Network Issues
```powershell
# If download fails, try different method
# Method 1: Direct curl
curl -L -o archive.tar.gz "https://github.com/owner/repo/archive/v1.2.3.tar.gz"

# Method 2: Browser download then calculate hash
Get-FileHash -Algorithm SHA512 "downloaded-file.tar.gz"
```

#### URL Changes
Sometimes upstream changes download URLs between versions:
```cmake
# Old URL pattern
REF v1.2.3
# URL: https://github.com/owner/repo/archive/v1.2.3.tar.gz

# New URL pattern  
REF release-1.2.4
# URL: https://github.com/owner/repo/archive/release-1.2.4.tar.gz
```

## 8. Registry Script Details

### registry-format.ps1
Formats all `vcpkg.json` files and ensures consistency:
```powershell
./scripts/registry-format.ps1 -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
```

### registry-add-version.ps1
Updates baseline and version files for a specific port:
```powershell
./scripts/registry-add-version.ps1 -PortName "port-name" -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
```

**Note:** This script requires a fresh git repository state and will fail if there are uncommitted changes to the port being registered.

## 9. Integration with vcpkg Commands

### Version Information Display
```powershell
# Show installed versions
vcpkg list port-name

# Show available versions (from registry)
vcpkg search port-name --x-full-desc
```

### Version-specific Installation
```powershell
# Install specific version (when multiple are available)
vcpkg install port-name@1.2.3
```

## 10. Related Resources

- [Main Port Update Guide](./guide-update-port.md)
- [vcpkg Versioning Documentation](https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json)
- [vcpkg Git Registry Concepts](https://learn.microsoft.com/en-us/vcpkg/maintainers/registries)
- [Registry Maintenance Scripts](../scripts/)