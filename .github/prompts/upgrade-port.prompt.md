---
description: 'Upgrade port to newer version with SHA512 calculation and testing'
agent: 'agent'
tools: ['edit/editFiles', 'search/fileSearch', 'search/readFile', 'runCommands/terminalLastCommand', 'runCommands/runInTerminal', 'fetch']
model: Claude Sonnet 4 (copilot)
---

# Upgrade Port

Update existing port to newer upstream version by modifying vcpkg.json and portfile.cmake, calculating new SHA512, and testing with --editable flag.

## Prompt Goals

- Read current port files (vcpkg.json, portfile.cmake)
- Update version in vcpkg.json
- Update REF and SHA512 in portfile.cmake
- Calculate new SHA512 for source archive
- Test installation with `--editable` flag
- Generate upgrade report with validation results
- Update work-note.md

## Workflow Expectation

**Default Behavior**: Autonomously reads port files, updates version/SHA512, tests with --editable, and reports results.

**Stop Conditions**:
- Port upgraded and tested successfully
- Port upgraded but test failed (report errors for user to fix)

**Prompt Forwarding**:
- If upgrade test succeeds: User should commit changes and run `./scripts/registry-add-version.ps1`
- If upgrade test fails: User must fix issues and retry `/install-port`

## User Input

Extract port name and target version from natural language input:

**Supported Patterns**:
- Port name with version: `openssl3 3.0.15`, `upgrade cpuinfo to 2024-01-15`
- Without version: `upgrade tensorflow-lite` (fetch latest from upstream)
- With URL: `upgrade openssl3 from https://github.com/openssl/openssl/releases/tag/openssl-3.0.15`

**Examples**:
```
Upgrade openssl3 to 3.0.15
Update cpuinfo to latest version
Upgrade tensorflow-lite to 2.14.1
```

## Process

### Phase 1: Analyze Current Port

#### Step 1.1: Read current vcpkg.json
- Tool: `#readFile`
- File: `ports/{port-name}/vcpkg.json`
- Extract: Current `version`, `homepage`

#### Step 1.2: Read current portfile.cmake
- Tool: `#readFile`
- File: `ports/{port-name}/portfile.cmake`
- Extract: `REPO` (GitHub owner/repo), `REF`, `SHA512`, `HEAD_REF`

#### Step 1.3: Determine target version
- Condition: Version specified in user input
  - Use: Specified version
- Condition: Version not specified
  - Action: Fetch latest release from upstream (use `/check-port-upstream` logic)
  - Tool: `#fetch`
  - URL: `{homepage}/releases/latest` or `https://api.github.com/repos/{owner}/{repo}/releases/latest`

### Phase 2: Gather New Version Information

#### Step 2.1: Normalize target version
- Strip: Leading 'v' if present (`v3.0.15` → `3.0.15`)
- Strip: Project name prefix (`openssl-3.0.15` → `3.0.15`)
- Format: Match vcpkg version format (semver or date)

#### Step 2.2: Construct source URL
- Pattern (GitHub): `https://github.com/{owner}/{repo}/archive/refs/tags/{tag}.tar.gz`
- Tag format: Use original upstream tag (may have 'v' prefix or project name)
- Example: `https://github.com/openssl/openssl/archive/refs/tags/openssl-3.0.15.tar.gz`

#### Step 2.3: Determine REF value
- Check: Does upstream use version tags with 'v' prefix?
- Check: Does upstream use project-name prefix?
- Examples:
  - `v${VERSION}` for projects using `v1.2.3` tags
  - `openssl-${VERSION}` for OpenSSL
  - `${VERSION}` for simple tags

### Phase 3: Calculate New SHA512

#### Step 3.1: Download source archive
- Tool: `#runInTerminal`
- Command (PowerShell):
  ```powershell
  $Version = "{target-version}"
  $Url = "{constructed-source-url}"
  curl -L -o "temp-${Version}.tar.gz" $Url
  ```
- Command (Bash/Zsh):
  ```bash
  version="{target-version}"
  url="{constructed-source-url}"
  curl -L -o "temp-${version}.tar.gz" "$url"
  ```
- Wait: Download completion

#### Step 3.2: Calculate SHA512
- Tool: `#runInTerminal`
- Command (PowerShell):
  ```powershell
  (Get-FileHash -Algorithm SHA512 "temp-${Version}.tar.gz").Hash.ToLower()
  ```
- Command (Bash/Zsh):
  ```bash
  sha512sum "temp-${version}.tar.gz" | awk '{print $1}'
  ```
- Capture: 128 character lowercase hex string

#### Step 3.3: Verify SHA512 format
- Check: Exactly 128 hex characters
- Check: Lowercase format (vcpkg preference)
- Purpose: Prevent malformed SHA512 values

#### Step 3.4: Clean up downloaded archive
- Tool: `#runInTerminal`
- Command (PowerShell): `Remove-Item "temp-${Version}.tar.gz"`
- Command (Bash/Zsh): `rm "temp-${version}.tar.gz"`

#### Step 3.5: Handle download failure
- Fallback: Use SHA512 value `0` as placeholder
- Note: vcpkg will report correct SHA512 on first install attempt
- User action: Update SHA512 after test installation

### Phase 4: Update Port Files

#### Step 4.1: Update vcpkg.json version
- Tool: `#editFiles`
- File: `ports/{port-name}/vcpkg.json`
- Change: `"version": "{old-version}"` → `"version": "{new-version}"`
- Preserve: All other fields unchanged

#### Step 4.2: Update portfile.cmake REF
- Tool: `#editFiles`
- File: `ports/{port-name}/portfile.cmake`
- Change: `REF {old-ref}` → `REF {new-ref}`
- Common patterns:
  - `REF v${VERSION}` (no change needed if using variable)
  - `REF openssl-${VERSION}` (no change needed)
  - `REF v1.2.3` → `REF v{new-version}` (hardcoded, needs update)

#### Step 4.3: Update portfile.cmake SHA512
- Tool: `#editFiles`
- File: `ports/{port-name}/portfile.cmake`
- Change: `SHA512 {old-sha512}` → `SHA512 {new-sha512}`
- Ensure: 128 lowercase hex characters

#### Step 4.4: Review other version references
- Check: Are there version numbers in comments?
- Check: Are there hardcoded version numbers in OPTIONS?
- Update: Any version-specific configuration if needed

### Phase 5: Test Upgrade with --editable

#### Step 5.1: Explain --editable flag
- Purpose: Test port changes without committing to registry
- Behavior: Allows iterative fixes without version registry conflicts
- Documentation: https://learn.microsoft.com/en-us/vcpkg/commands/install#editable-mode

#### Step 5.2: Run vcpkg install with --editable
- Tool: `#runInTerminal`
- Command (PowerShell):
  ```powershell
  vcpkg install --editable `
    --overlay-ports ./ports `
    --x-buildtrees-root buildtrees `
    --x-packages-root packages `
    --x-install-root installed `
    {port-name}
  ```
- Command (Bash/Zsh):
  ```bash
  vcpkg install --editable \
    --overlay-ports ./ports \
    --x-buildtrees-root buildtrees \
    --x-packages-root packages \
    --x-install-root installed \
    {port-name}
  ```
- Wait: Installation completion (may take several minutes)

#### Step 5.3: Capture test results
- Tool: `#terminalLastCommand`
- Purpose: Get full installation log

#### Step 5.4: Analyze test results
- Success: Exit code 0, "successfully installed" message
- Failure: Non-zero exit code, error messages
- If failed: Read build logs (same as `/install-port` Phase 4)

### Phase 6: Handle Test Results

#### Step 6.1: If test succeeds
- Action: Prepare for version commit
- Next steps: User commits changes and runs `registry-add-version.ps1`

#### Step 6.2: If test fails with SHA512 error
- Check: Error message contains "SHA512 mismatch"
- Action: Extract correct SHA512 from error message
- Tool: `#editFiles`
- Update: portfile.cmake with correct SHA512
- Retry: Run test installation again

#### Step 6.3: If test fails with build errors
- Action: Analyze build logs (use `/install-port` logic)
- Report: Common error patterns
- Suggest: Port may need patches for new version
- Next: User must fix build issues

#### Step 6.4: Check for breaking changes
- Condition: Major version upgrade or build failures
- Suggest: Review upstream changelog
- Suggest: May need new patches or portfile adjustments

### Phase 7: Validate File Changes

#### Step 7.1: Re-read updated vcpkg.json
- Tool: `#readFile`
- File: `ports/{port-name}/vcpkg.json`
- Verify: Version updated correctly

#### Step 7.2: Re-read updated portfile.cmake
- Tool: `#readFile`
- File: `ports/{port-name}/portfile.cmake`
- Verify: SHA512 updated correctly
- Verify: REF updated if needed

#### Step 7.3: Run format-manifest (optional)
- Tool: `#runInTerminal`
- Command:
  ```powershell
  ./scripts/registry-format.ps1 -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
  ```
- Purpose: Ensure vcpkg.json formatting correct

### Phase 8: Generate Upgrade Report

#### Step 8.1: Compile upgrade summary
- List: Version change, SHA512 change, test results
- Include: Any errors or warnings

#### Step 8.2: Update work-note.md
- Tool: `#editFiles` (append mode)
- Content: Upgrade details with timestamp

## Reporting

### Successful Upgrade

```markdown
# Port Upgrade Report

**Port**: `openssl3`
**Old Version**: 3.0.13
**New Version**: 3.0.15
**Date**: 2025-11-26 15:05:30

## Changes

### vcpkg.json
- ✅ `version`: "3.0.13" → "3.0.15"

### portfile.cmake
- ✅ `REF`: openssl-${VERSION} (no change, uses variable)
- ✅ `SHA512`: `8a7e4c2f...` → `f3b9d1e8...` (updated)

## SHA512 Calculation

Downloaded source archive from:
```
https://github.com/openssl/openssl/archive/refs/tags/openssl-3.0.15.tar.gz
```

Calculated SHA512:
```
f3b9d1e89a2c4f7e... (128 characters)
```

## Test Results

✅ **Test Installation Successful** (with --editable flag)

### Test Command

```powershell
vcpkg install --editable --overlay-ports ./ports openssl3:x64-windows
```

### Output

```
Starting package 1/1: openssl3:x64-windows
Building package openssl3[core]:x64-windows...
-- Using cached openssl-openssl-3.0.15.tar.gz
-- Cleaning sources at C:/..../buildtrees/openssl3/src/ssl-3.0.15-....
-- Extracting source C:/..../downloads/openssl-openssl-3.0.15.tar.gz
...
-- Performing post-build validation
Stored binary cache: ...
-- Performing post-build validation done
Elapsed time to handle openssl3:x64-windows: 2 min 45 s
Total install time: 2 min 45 s
openssl3:x64-windows package is successfully installed.
```

### Installed Files

- Headers: `installed/x64-windows/include/openssl/*.h`
- Libraries: `libssl.lib`, `libcrypto.lib`
- Binaries: `libssl-3-x64.dll`, `libcrypto-3-x64.dll`

## Validation

✅ Version updated correctly in vcpkg.json
✅ SHA512 updated correctly in portfile.cmake
✅ Test installation succeeded
✅ Binary cache created

## Next Steps

### 1. Commit Port Changes

```powershell
git add ports/openssl3/
git commit -m "[openssl3] update to 3.0.15" -m "- Security fixes: CVE-2024-XXXX"
```

### 2. Update Registry Baseline

```powershell
./scripts/registry-add-version.ps1 -PortName "openssl3" -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
```

### 3. Commit Version Files

```powershell
git add versions/
git commit -m "[openssl3] update baseline and version files"
```

### 4. (Optional) Test Without --editable

Remove cached packages and test final installation:
```powershell
Remove-Item -Recurse packages/openssl3_*
vcpkg install --overlay-ports ./ports openssl3:x64-windows
```

## Upstream Changes

See release notes: https://github.com/openssl/openssl/releases/tag/openssl-3.0.15

### Highlights
- Security fixes for CVE-2024-XXXX
- Performance improvements
- Bug fixes for Windows builds

### Breaking Changes
None reported
```

### Upgrade with SHA512 Correction

```markdown
# Port Upgrade Report

**Port**: `cpuinfo`
**Old Version**: 2023-08-02
**New Version**: 2024-01-15
**Date**: 2025-11-26 15:10:45

## Changes

### vcpkg.json
- ✅ `version`: "2023-08-02" → "2024-01-15"

### portfile.cmake
- ✅ `REF`: ${VERSION} (no change)
- ✅ `SHA512`: Initially incorrect, corrected after test

## SHA512 Calculation

### Initial Attempt (Failed)

Used placeholder SHA512 `0` due to download timeout.

### Correction from vcpkg Test

vcpkg reported correct SHA512 during test installation:
```
error: SHA512 mismatch detected
Expected: 0
Actual: a2c4f7e3b9d1e8f6...
```

Updated portfile.cmake with correct value.

## Test Results

✅ **Test Installation Successful** (after SHA512 correction)

### Iterations

1. **First attempt**: SHA512 mismatch (expected)
   - Used placeholder `0`
   - vcpkg reported actual SHA512
   
2. **Second attempt**: Success
   - Updated with correct SHA512: `a2c4f7e3b9d1e8f6...`
   - Installation completed successfully

## Next Steps

1. Commit port changes
2. Run `registry-add-version.ps1`
3. Commit version files

## Note

**Placeholder SHA512 Strategy**: Useful when download fails or checksum calculation unavailable. vcpkg will report correct value on first install attempt.
```

### Upgrade Failed - Build Errors

```markdown
# Port Upgrade Report

**Port**: `tensorflow-lite`
**Old Version**: 2.14.0
**New Version**: 2.15.0
**Date**: 2025-11-26 15:15:20

## Changes

### vcpkg.json
- ✅ `version`: "2.14.0" → "2.15.0"

### portfile.cmake
- ✅ `REF`: v${VERSION}
- ✅ `SHA512`: `f3b9d1e8...` (calculated and updated)

## SHA512 Calculation

✅ Successfully calculated SHA512:
```
f3b9d1e89a2c4f7e3b6d5c8a9e2f4c7b1d8e3f9a6c5d2b7e4f1c8d9b2a3f6e5c4
```

## Test Results

❌ **Test Installation Failed**

### Error Summary

Compiler error - API changes in TensorFlow 2.15.0

### Error Details

```
C:\...\tensorflow\lite\kernels\internal\reference\integer_ops\add.h(42):
error C2065: 'ActivationFunctionType': undeclared identifier

C:\...\tensorflow\lite\kernels\internal\reference\integer_ops\add.h(42):
error C2065: 'kNone': undeclared identifier
```

### Log Location

`buildtrees/tensorflow-lite/build-x64-windows-out.log` (lines 2450-2460)

## Diagnosis

⚠️ **Breaking API Changes**: TensorFlow 2.15.0 changed internal API

### Root Cause

Enum type `ActivationFunctionType` moved to different header or renamed.

### Recommended Fixes

**Option 1**: Create patch for API changes
```cmake
vcpkg_apply_patches(
    SOURCE_PATH "${SOURCE_PATH}"
    PATCHES
        fix-activation-type-2.15.patch
)
```

**Option 2**: Check upstream vcpkg
- Search: microsoft/vcpkg for tensorflow-lite 2.15 patches
- URL: https://github.com/microsoft/vcpkg/tree/master/ports/tensorflow-lite

**Option 3**: Check upstream TensorFlow
- Issue: Search TensorFlow issues for build errors
- URL: https://github.com/tensorflow/tensorflow/issues

## Breaking Changes

Major API changes detected in TensorFlow 2.15:
- Internal kernel API reorganization
- Activation function type changes

## Next Steps

### 1. Research Upstream Solutions

Check if microsoft/vcpkg has patches for 2.15:
```powershell
/check-port-upstream tensorflow-lite
```

### 2. Create Patches

If no upstream patches:
1. Identify API changes from TensorFlow changelog
2. Create patch file: `ports/tensorflow-lite/fix-api-2.15.patch`
3. Update portfile.cmake to apply patch

### 3. Alternative: Stay on 2.14.0

If patches too complex:
- Revert changes: `git checkout ports/tensorflow-lite/`
- Wait for microsoft/vcpkg to handle 2.15
- Monitor: https://github.com/microsoft/vcpkg/pulls?q=tensorflow-lite

## Recommendation

⚠️ **Do not proceed with upgrade** until build errors resolved.

Consider:
1. Research upstream patches first
2. If patches available, apply and retry
3. If patches unavailable, stay on 2.14.0

## Rollback Command

```powershell
git checkout ports/tensorflow-lite/vcpkg.json
git checkout ports/tensorflow-lite/portfile.cmake
```
```

### Major Version Upgrade Warning

```markdown
# Port Upgrade Report

**Port**: `zlib-ng`
**Old Version**: 2.1.7
**New Version**: 3.0.2
**Date**: 2025-11-26 15:20:15

## Changes

### vcpkg.json
- ⚠️ `version`: "2.1.7" → "3.0.2" (**Major version bump**)

### portfile.cmake
- ✅ `REF`: v${VERSION}
- ✅ `SHA512`: `c4f7e3b9...` (calculated)

## Major Version Warning

⚠️ **Major version upgrade detected: 2.x → 3.x**

### Breaking Changes

Review release notes carefully:
- https://github.com/zlib-ng/zlib-ng/releases/tag/3.0.0

Potential breaking changes:
- API function signature changes
- Removed deprecated functions
- Configuration option changes

## Dependency Impact

Ports depending on zlib-ng:
```powershell
vcpkg depend-info zlib-ng --overlay-ports ./ports
```

⚠️ **Warning**: Upgrading may break dependent ports

## Recommendations

### Option 1: Test Carefully
1. Complete upgrade
2. Test all dependent ports
3. Update dependent ports if needed

### Option 2: Create Separate Port
- Keep `zlib-ng` at 2.1.7
- Create new port `zlib-ng3` for 3.x
- Allow gradual migration

### Option 3: Wait for Upstream
- Let microsoft/vcpkg handle major version
- Adopt their migration strategy

## Current Status

⚠️ **Upgrade paused for user decision**

## Next Steps

**User Decision Required**:

1. **Proceed with upgrade** (risky):
   ```powershell
   /install-port zlib-ng
   ```
   Then test all dependent ports.

2. **Create separate port** (safer):
   ```powershell
   /create-port https://github.com/zlib-ng/zlib-ng version 3.0.2
   ```
   Name it `zlib-ng3`.

3. **Cancel upgrade** (conservative):
   ```powershell
   git checkout ports/zlib-ng/
   ```
   Stay on 2.1.7 until upstream handles migration.

**Recommendation**: Option 3 (wait for upstream guidance)
```

## Work Note Entry

### Success

```markdown
## 2025-11-26 15:05:30 - /upgrade-port

✅ Port upgraded successfully
- Port: openssl3
- Version: 3.0.13 → 3.0.15
- SHA512: Updated
- Test: Passed (with --editable)
- Next: Commit changes and run registry-add-version.ps1
```

### Failure

```markdown
## 2025-11-26 15:15:20 - /upgrade-port

❌ Port upgrade failed
- Port: tensorflow-lite
- Version: 2.14.0 → 2.15.0
- SHA512: Calculated
- Test: Failed (build errors)
- Error: API breaking changes
- Recommendation: Create patches or wait for upstream
```

### Major Version Warning

```markdown
## 2025-11-26 15:20:15 - /upgrade-port

⚠️ Major version upgrade detected
- Port: zlib-ng
- Version: 2.1.7 → 3.0.2 (major bump)
- Status: Paused for user decision
- Recommendation: Wait for upstream or create separate port (zlib-ng3)
```
