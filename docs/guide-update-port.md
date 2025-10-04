# Guide: Updating an Existing Port

This document provides the **end-to-end workflow** for updating existing ports in this registry. For creating new ports, see the [new port creation guide](./guide-new-port.md).

Companion documents:
- [Version management patterns](./guide-update-port-versioning.md)

## 1. High-Level Update Phases

### Research Phase
**Goal:** Understand upstream changes  
**Output:** Work notes and change analysis

Research the new upstream version to understand what changed, identify potential breaking changes, and assess impact on existing patches.

### Version Update Phase
**Goal:** Update version metadata  
**Output:** Updated `vcpkg.json` and `portfile.cmake`

Update version information and calculate new SHA512 hash for the updated source.

### Patch Maintenance Phase
**Goal:** Ensure patches still apply  
**Output:** Updated, removed, or new patch files

Review and update existing patches, remove obsolete ones, or create new patches as needed.

### Build Validation Phase
**Goal:** Ensure clean build and installation  
**Output:** Successful test installations

Validate that the updated port builds correctly across target platforms.

### Registry Update Phase
**Goal:** Update version tracking  
**Output:** Updated `versions/*` files and commits

Use registry scripts to update baseline and version tracking files.

### Documentation Phase
**Goal:** Record update decisions  
**Output:** Updated commit messages

Document any special decisions or known issues discovered during the update.

## 2. Detailed Update Workflow

### Step 1: Research the Update

1. **Check upstream changes:**
   ```powershell
   # Review release notes, changelog, or commit history
   # Note: Replace with actual upstream repository
   $UpstreamUrl = "https://github.com/owner/repo"
   $OldVersion = "1.2.3"
   $NewVersion = "1.3.0"
   
   # Compare releases
   Start-Process "$UpstreamUrl/compare/v$OldVersion...v$NewVersion"
   ```

2. **Identify potential impacts:**
   - API/ABI changes
   - Build system modifications
   - New dependencies
   - Removed features
   - License changes

### Step 2: Update Version Information

Following the [version management guide](./guide-update-port-versioning.md):

1. **Update `vcpkg.json`:**
   ```json
   {
     "name": "port-name",
     "version": "1.3.0",
     "description": "...",
     "homepage": "...",
     "license": "..."
   }
   ```

2. **Update `portfile.cmake`:**
   ```cmake
   vcpkg_from_github(
       OUT_SOURCE_PATH SOURCE_PATH
       REPO owner/repo
       REF v1.3.0  # Update this
       SHA512 0    # Use 0 initially, then update with calculated hash
       HEAD_REF main
   )
   ```

3. **Calculate SHA512 hash:**
   ```powershell
   # Method 1: Use our helper script (if available)
   ./scripts/update-portfile-sha512.ps1 -PortName "port-name"
   
   # Method 2: Manual calculation
   $Version = "1.3.0"
   $Url = "https://github.com/owner/repo/archive/v$Version.tar.gz"
   curl -L -o "temp-$Version.tar.gz" $Url
   $Hash = (Get-FileHash -Algorithm SHA512 "temp-$Version.tar.gz").Hash.ToLower()
   Write-Host "SHA512: $Hash"
   Remove-Item "temp-$Version.tar.gz"
   ```

### Step 3: Handle Patches

Following the [patch maintenance guide](./guide-update-port-patches.md):

1. **Test existing patches:**
   ```powershell
   # Try building with existing patches
   vcpkg install --overlay-ports=ports port-name
   ```

2. **Update patches if needed:**
   - If patches fail to apply, update them for the new version
   - Remove patches that are no longer needed
   - Create new patches for new issues

3. **Consider embedded CMakeLists.txt approach:**
   - For complex cases where patches become unwieldy
   - See [patch maintenance guide](./guide-update-port-patches.md) for details

### Step 4: Test the Update

1. **Clean installation test:**
   ```powershell
   # Test with overlay ports
   vcpkg install --overlay-ports=ports --triplet x64-windows port-name
   
   # Remove and test again
   vcpkg remove port-name
   vcpkg install --overlay-ports=ports --triplet x64-windows port-name
   ```

2. **Multi-platform testing:**
   ```powershell
   # Test on different triplets
   vcpkg install --overlay-ports=ports --triplet x64-linux port-name
   vcpkg install --overlay-ports=ports --triplet x64-osx port-name
   ```

3. **Feature testing (if applicable):**
   ```powershell
   # Test with features
   vcpkg install --overlay-ports=ports port-name[feature1,feature2]
   ```

### Step 5: Format and Register

1. **Format the port files:**
   ```powershell
   ./scripts/registry-format.ps1 -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
   ```

2. **Commit port changes:**
   ```powershell
   git add ./ports/port-name/
   git commit -m "[port-name] update to v1.3.0" -m "- $UpstreamUrl/releases/tag/v1.3.0"
   ```

3. **Update registry baseline:**
   ```powershell
   ./scripts/registry-add-version.ps1 -PortName "port-name" -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
   ```

4. **Commit version changes:**
   ```powershell
   git add ./versions/
   git commit -m "[port-name] update baseline and version files for v1.3.0"
   ```

## 3. Update Checklist

### Pre-Update Research
- [ ] Reviewed upstream release notes/changelog
- [ ] Identified potential breaking changes
- [ ] Checked for new dependencies
- [ ] Noted any license changes

### Version Updates
- [ ] Updated version in `vcpkg.json`
- [ ] Updated `REF` in `portfile.cmake`
- [ ] Calculated and updated `SHA512` hash
- [ ] Verified download URL accessibility

### Patch Management
- [ ] Tested existing patches with new version
- [ ] Updated patches that failed to apply
- [ ] Removed obsolete patches
- [ ] Created new patches if needed
- [ ] Documented patch changes

### Testing & Validation
- [ ] Port installs successfully with overlay
- [ ] No unexpected files in package directory
- [ ] License file properly installed
- [ ] All features work (if applicable)
- [ ] Multi-platform testing completed
- [ ] No regression in functionality

### Registry Integration
- [ ] Port files formatted with registry script
- [ ] Port changes committed with proper message
- [ ] Registry baseline updated with script
- [ ] Version files committed with proper message
- [ ] Fresh git state maintained throughout

### Documentation
- [ ] Commit messages follow convention
- [ ] Known issues documented
- [ ] Breaking changes noted (if any)

## 4. Best Practices

### Version Management
- Always use immutable references (tags/commits, not branches)
- Verify SHA512 hashes before committing
- Keep version updates minimal and focused

### Patch Strategy
- Prefer minimal patches over extensive modifications
- Document patch purposes clearly
- Consider upstream contributions for widely applicable fixes
- Use embedded CMakeLists.txt for complex build system changes

### Testing Approach
- Test both clean installs and updates
- Validate all supported features
- Check multiple platforms when possible
- Verify integration with consumer projects

### Commit Organization
- Separate port changes from version registration
- Use descriptive commit messages with upstream links
- Maintain clean git history for easier troubleshooting

## 5. Common Scenarios

### Simple Version Bump
- No breaking changes
- Patches apply cleanly
- Standard workflow applies

### API Breaking Changes
- Review consumer compatibility
- Document breaking changes clearly
- Consider feature flags for backward compatibility

### Build System Changes
- May require patch updates
- Consider embedded CMakeLists.txt approach
- Test thoroughly across platforms

### Dependency Changes
- Update dependency list in `vcpkg.json`
- Verify all dependencies are available
- Test dependency resolution

## 6. Related Resources

- [New Port Creation](./guide-new-port.md)
- [Version Management](./guide-update-port-versioning.md)
- [Patch Maintenance](./guide-update-port-patches.md)
- [Review Checklist](./review-checklist.md)
- [vcpkg Documentation](https://learn.microsoft.com/en-us/vcpkg/)
- [Registry Scripts](../scripts/)