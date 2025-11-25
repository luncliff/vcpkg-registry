---
description: 'Review port files against vcpkg guidelines and best practices'
agent: 'agent'
tools: ['edit/editFiles', 'search/fileSearch', 'search/textSearch', 'search/readFile', 'fetch']
model: Claude Sonnet 4 (copilot)
---

# Review Port

Validate port files (vcpkg.json, portfile.cmake, patches, usage) against vcpkg contribution guidelines and registry best practices.

## Prompt Goals

- Locate and read all port files
- Fetch vcpkg contribution guidelines and maintainer guide
- Validate vcpkg.json structure (schema compliance, version format, dependencies)
- Validate portfile.cmake (helper function usage, SHA512 format, copyright handling)
- Check for required files (usage, copyright notice)
- Identify violations and suggest corrections
- Generate comprehensive review report

## Workflow Expectation

**Default Behavior**: Autonomously reads port files, fetches guidelines, validates structure, and generates detailed review report.

**Stop Conditions**:
- Review completed with pass/fail status
- All violations documented with fix recommendations

**Prompt Forwarding**:
- If review passes: User may proceed to add version (`./scripts/registry-add-version.ps1`)
- If review fails: User must fix violations and re-run `/review-port`

## User Input

Extract port name from natural language input:

**Supported Patterns**:
- Port names: `openssl3`, `tensorflow-lite`
- With path: `review ports/openssl3`
- Batch review: `review openssl3 zlib-ng cpuinfo`

**Examples**:
```
Review openssl3 port
Check if tensorflow-lite follows guidelines
Validate cpuinfo port files
```

## Process

### Phase 1: Locate Port Files

#### Step 1.1: Find port directory
- Tool: `#fileSearch`
- Pattern: `ports/{port-name}/vcpkg.json`
- Purpose: Verify port exists

#### Step 1.2: List all port files
- Tool: `#fileSearch`
- Pattern: `ports/{port-name}/**/*`
- Purpose: Get complete file inventory

#### Step 1.3: Identify file types
- Categorize: `vcpkg.json`, `portfile.cmake`, `*.patch`, `usage`, `copyright`, `CMakeLists.txt`, others
- Purpose: Determine which files need review

### Phase 2: Fetch vcpkg Guidelines

#### Step 2.1: Fetch contribution guidelines
- Tool: `#fetch`
- URL: `https://github.com/microsoft/vcpkg/blob/master/CONTRIBUTING.md`
- Purpose: Get latest contribution requirements

#### Step 2.2: Fetch maintainer guide
- Tool: `#fetch`
- URL: `https://github.com/microsoft/vcpkg-docs/blob/main/vcpkg/contributing/maintainer-guide.md`
- Purpose: Get port maintenance best practices

#### Step 2.3: Load local review checklist
- Tool: `#readFile`
- File: `docs/review-checklist.md`
- Purpose: Apply repository-specific checks

#### Step 2.4: Load local copilot instructions
- Tool: `#readFile`
- File: `.github/copilot-instructions.md`
- Purpose: Check for experimental guidelines (embedded CMakeLists.txt, patches)

### Phase 3: Validate vcpkg.json

#### Step 3.1: Read vcpkg.json
- Tool: `#readFile`
- File: `ports/{port-name}/vcpkg.json`

#### Step 3.2: Check required fields
- Validate presence: `name`, `version`, `description`
- Optional but recommended: `homepage`, `license`, `supports`

#### Step 3.3: Validate version format
- Check: No leading 'v' (use `3.0.15`, not `v3.0.15`)
- Check: Valid semver or date format (`2023-08-02`, `1.2.3`, `1.2.3-beta.4`)
- Check: No version suffix in name (use `openssl3`, not `openssl-3.0`)

#### Step 3.4: Validate dependencies
- Check: Dependencies exist in registry or upstream
- Check: Build tools use `"host"` platform (`"vcpkg-cmake": { "host": true }` or old format)
- Check: Platform-specific dependencies use proper syntax

#### Step 3.5: Validate license field
- Check: SPDX identifier format (https://spdx.org/licenses/)
- Examples: `MIT`, `Apache-2.0`, `BSD-3-Clause`, `GPL-3.0-or-later`
- Check: Matches actual project license

#### Step 3.6: Check for features
- Validate: Feature names (lowercase, no special characters except hyphens)
- Validate: Feature descriptions present
- Check: Features have proper dependencies

### Phase 4: Validate portfile.cmake

#### Step 4.1: Read portfile.cmake
- Tool: `#readFile`
- File: `ports/{port-name}/portfile.cmake`

#### Step 4.2: Validate source acquisition
- Check: Uses `vcpkg_from_github`, `vcpkg_from_gitlab`, or `vcpkg_download_distfile`
- Check: `REF` uses `${VERSION}` variable or proper git tag
- Check: `SHA512` is 128 hex characters (lowercase preferred)
- Check: `HEAD_REF` specified for vcpkg_from_github

#### Step 4.3: Validate build system helpers
- Check: Uses vcpkg helper functions (`vcpkg_cmake_configure`, `vcpkg_cmake_install`, `vcpkg_cmake_config_fixup`)
- Avoid: Manual CMake invocations (`execute_process(COMMAND cmake ...)`)
- Check: Build system matches project (CMake, Meson, autotools)

#### Step 4.4: Validate installation steps
- Check: Removes debug headers (`file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")`)
- Check: Removes debug share (`file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")`)
- Check: Handles CMake config fixup (`vcpkg_cmake_config_fixup` or `vcpkg_fixup_cmake_targets`)

#### Step 4.5: Validate copyright handling
- Check: Uses `vcpkg_install_copyright(FILE_LIST ...)` (preferred)
- Alternative: `file(INSTALL ... DESTINATION ... RENAME copyright)` (deprecated)
- Check: LICENSE file path correct

#### Step 4.6: Check for deprecated functions
- Deprecated: `vcpkg_fixup_cmake_targets()` → use `vcpkg_cmake_config_fixup()`
- Deprecated: `vcpkg_copy_pdbs()` → automatic in modern vcpkg
- Deprecated: Manual copyright installation → use `vcpkg_install_copyright`

#### Step 4.7: Validate patch application (if patches exist)
- Check: Uses `vcpkg_apply_patches` or `PATCHES` argument in `vcpkg_from_github`
- Check: Patch files exist in port directory
- Check: Patch context explains purpose

### Phase 5: Validate Additional Files

#### Step 5.1: Check for usage file
- Tool: `#fileSearch`
- Pattern: `ports/{port-name}/usage`
- Recommended: If port provides CMake config or pkg-config

#### Step 5.2: Read usage file (if exists)
- Tool: `#readFile`
- File: `ports/{port-name}/usage`
- Validate: Provides clear `find_package` and `target_link_libraries` example

#### Step 5.3: Check for embedded CMakeLists.txt
- Tool: `#fileSearch`
- Pattern: `ports/{port-name}/CMakeLists.txt`
- Warning: Experimental approach, document rationale

#### Step 5.4: Validate patch files (if exist)
- Tool: `#readFile`
- Files: `ports/{port-name}/*.patch`
- Check: Patches have descriptive names
- Check: Patch context explains purpose (comments in portfile.cmake)

#### Step 5.5: Check for unnecessary files
- Avoid: Binary files, large test data, generated files
- Avoid: Duplicate documentation (prefer upstream README)

### Phase 6: Cross-Reference with Baseline

#### Step 6.1: Check versions baseline
- Tool: `#readFile`
- File: `versions/baseline.json`
- Validate: Port listed in baseline

#### Step 6.2: Check version history
- Tool: `#readFile`
- File: `versions/{first-letter}-/{port-name}.json`
- Validate: Version history exists (if port previously added)

### Phase 7: Generate Review Report

#### Step 7.1: Compile validation results
- Categorize: Critical issues, warnings, suggestions
- Format: Structured markdown with pass/fail sections

#### Step 7.2: Update work-note.md
- Tool: `#editFiles` (append mode)
- Content: Review summary with timestamp

## Reporting

### Review Passed

```markdown
# Port Review Report

**Port**: `cpuinfo`
**Date**: 2025-11-26 13:10:30

## Overall Result

✅ **PASS** - Port meets guidelines

## File Inventory

- ✅ `vcpkg.json` (277 bytes)
- ✅ `portfile.cmake` (531 bytes)
- ✅ `usage` (185 bytes)

## vcpkg.json Validation

### Required Fields
- ✅ `name`: "cpuinfo"
- ✅ `version`: "2023-08-02"
- ✅ `description`: "CPU INFOrmation library (x86/x86-64/ARM/ARM64, Linux/Windows/Android/macOS/iOS)"

### Optional Fields
- ✅ `homepage`: "https://github.com/pytorch/cpuinfo"
- ✅ `license`: "BSD-2-Clause"

### Dependencies
- ✅ `vcpkg-cmake` (host tool)
- ✅ `vcpkg-cmake-config` (host tool)

### Version Format
- ✅ Uses date format: "2023-08-02"
- ✅ No leading 'v'

## portfile.cmake Validation

### Source Acquisition
- ✅ Uses `vcpkg_from_github`
- ✅ `REPO`: pytorch/cpuinfo
- ✅ `REF`: ${VERSION}
- ✅ `SHA512`: Valid (128 characters, lowercase)
- ✅ `HEAD_REF`: main

### Build System
- ✅ Uses `vcpkg_cmake_configure`
- ✅ Uses `vcpkg_cmake_install`
- ✅ Uses `vcpkg_cmake_config_fixup`

### Installation Cleanup
- ✅ Removes debug headers
- ✅ Removes debug share

### Copyright
- ✅ Uses `vcpkg_install_copyright(FILE_LIST ...)`
- ✅ LICENSE path correct

## Additional Files

### usage
- ✅ Present and well-documented
- ✅ Provides CMake example:
  ```cmake
  find_package(cpuinfo CONFIG REQUIRED)
  target_link_libraries(main PRIVATE cpuinfo::cpuinfo)
  ```

## Baseline Check

- ✅ Listed in `versions/baseline.json`
- ✅ Version history in `versions/c-/cpuinfo.json`

## Recommendations

✅ No issues found. Port is ready for use.

## Next Steps

Port passed review. You can now:
1. Use the port in projects
2. Update baseline if version changed: `./scripts/registry-add-version.ps1 -PortName "cpuinfo"`
```

### Review Failed - vcpkg.json Issues

```markdown
# Port Review Report

**Port**: `example-lib`
**Date**: 2025-11-26 13:15:45

## Overall Result

❌ **FAIL** - Critical issues found

## File Inventory

- ⚠️ `vcpkg.json` (incomplete)
- ✅ `portfile.cmake`
- ❌ `usage` (missing)

## vcpkg.json Validation

### Required Fields
- ✅ `name`: "example-lib"
- ❌ **MISSING**: `version`
- ✅ `description`: "Example library"

### Optional Fields
- ❌ **MISSING**: `homepage` (recommended)
- ⚠️ `license`: Not specified (recommended)

### Dependencies
- ⚠️ `zlib`: Should specify build tool platform
  - Fix: Use `{ "name": "vcpkg-cmake", "host": true }`

### Version Format
- ❌ **ERROR**: No version field present
  - Fix: Add `"version": "1.0.0"` to vcpkg.json

## portfile.cmake Validation

### Source Acquisition
- ✅ Uses `vcpkg_from_github`
- ⚠️ `SHA512`: Uses uppercase (prefer lowercase)
  - Fix: Convert SHA512 to lowercase

### Build System
- ✅ Uses `vcpkg_cmake_configure`
- ✅ Uses `vcpkg_cmake_install`
- ✅ Uses `vcpkg_cmake_config_fixup`

### Installation Cleanup
- ✅ Removes debug headers
- ❌ **MISSING**: Debug share removal
  - Fix: Add `file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")`

### Copyright
- ⚠️ Uses deprecated `file(INSTALL ... RENAME copyright)`
  - Fix: Use `vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")`

## Additional Files

### usage
- ❌ **MISSING**: No usage file
  - Recommendation: Create `ports/example-lib/usage` with CMake example

## Baseline Check

- ❌ **NOT LISTED**: Port not in `versions/baseline.json`
  - Fix: Run `./scripts/registry-add-version.ps1 -PortName "example-lib"`

## Critical Issues (Must Fix)

1. **Missing version field in vcpkg.json**
   ```json
   {
     "name": "example-lib",
     "version": "1.0.0",
     ...
   }
   ```

2. **Missing debug share removal in portfile.cmake**
   ```cmake
   file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
   file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")
   ```

3. **Port not in baseline** - Run registry-add-version.ps1

## Warnings (Recommended Fixes)

1. **Add homepage to vcpkg.json**
   ```json
   "homepage": "https://github.com/owner/example-lib"
   ```

2. **Add license to vcpkg.json**
   ```json
   "license": "MIT"
   ```

3. **Modernize copyright installation**
   ```cmake
   vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
   ```

4. **Convert SHA512 to lowercase**

5. **Create usage file** with CMake example

## Next Steps

1. Fix critical issues
2. Re-run `/review-port example-lib`
3. After passing review, test with `/install-port example-lib`
```

### Review with Experimental Features

```markdown
# Port Review Report

**Port**: `farmhash`
**Date**: 2025-11-26 13:20:15

## Overall Result

✅ **PASS** (with experimental features)

## File Inventory

- ✅ `vcpkg.json`
- ✅ `portfile.cmake`
- ⚠️ **Experimental**: `CMakeLists.txt` (embedded)

## vcpkg.json Validation

✅ All required fields present

## portfile.cmake Validation

### Source Acquisition
- ✅ Uses `vcpkg_from_github`
- ✅ SHA512 valid

### Experimental: Embedded CMakeLists.txt
- ⚠️ Port uses embedded `CMakeLists.txt` approach
- File copied to source during build: `file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")`

**Rationale** (from copilot-instructions.md):
- Original build system too complex (autotools)
- Embedded approach simplifies maintenance
- Acceptable for experimental/private registries

**Upstream Contribution Warning**:
If contributing to microsoft/vcpkg, convert embedded CMakeLists.txt to patch files:
1. Generate patch: `git diff` or `diff` tools
2. Replace `file(COPY ...)` with `vcpkg_apply_patches`
3. Follow upstream guidelines

### Build System
- ✅ Uses `vcpkg_cmake_configure`
- ✅ Uses `vcpkg_cmake_install`

### Copyright
- ✅ Uses `vcpkg_install_copyright`

## Recommendations

✅ Port follows repository guidelines (allows experimental approaches)

⚠️ **If contributing upstream**: Convert embedded CMakeLists.txt to patch

## Next Steps

Port passed review. Experimental feature documented and justified.
```

### Review with Patch Files

```markdown
# Port Review Report

**Port**: `tensorflow-lite`
**Date**: 2025-11-26 13:25:30

## Overall Result

✅ **PASS**

## File Inventory

- ✅ `vcpkg.json`
- ✅ `portfile.cmake`
- ✅ `usage`
- ✅ `fix-msvc-build.patch`
- ✅ `fix-android-build.patch`

## vcpkg.json Validation

✅ All fields valid

## portfile.cmake Validation

### Patch Application
- ✅ Uses `PATCHES` argument in `vcpkg_from_github`:
  ```cmake
  vcpkg_from_github(
      OUT_SOURCE_PATH SOURCE_PATH
      REPO tensorflow/tensorflow
      REF v${VERSION}
      SHA512 ...
      HEAD_REF master
      PATCHES
          fix-msvc-build.patch
          fix-android-build.patch
  )
  ```

### Patch Files

#### fix-msvc-build.patch
- ✅ Descriptive filename
- ✅ Purpose documented in portfile comments
- Purpose: Fix MSVC `/permissive-` compiler errors

#### fix-android-build.patch
- ✅ Descriptive filename
- ✅ Purpose documented
- Purpose: Add Android NDK detection

### Build System
- ✅ Uses vcpkg CMake helpers

### Copyright
- ✅ Uses `vcpkg_install_copyright`

## Recommendations

✅ Patches well-documented and necessary

✅ Port follows best practices

## Next Steps

Port passed review with properly maintained patches.
```

## Work Note Entry

### Pass

```markdown
## 2025-11-26 13:10:30 - /review-port

✅ Review passed
- Port: cpuinfo
- Issues: None
- Recommendations: None
- Status: Ready for use
```

### Fail

```markdown
## 2025-11-26 13:15:45 - /review-port

❌ Review failed
- Port: example-lib
- Critical issues: 3 (missing version, missing debug cleanup, not in baseline)
- Warnings: 5 (missing homepage, license, usage file, etc.)
- Next: Fix critical issues and re-run review
```
