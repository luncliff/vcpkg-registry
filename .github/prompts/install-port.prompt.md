---
description: 'Install vcpkg port with overlay-ports and analyze build logs'
agent: 'agent'
tools: ['edit/editFiles', 'search/fileSearch', 'search/readFile', 'runCommands/terminalLastCommand', 'runCommands/runInTerminal']
model: GPT-5 mini (copilot)
---

# Install Port

Execute vcpkg port installation with overlay-ports, monitor build process, and analyze results (success or failure).

## Prompt Goals

- Parse port installation request with features
- Execute `vcpkg install` with correct overlay-ports configuration
- Monitor terminal output for errors
- Analyze build logs if installation fails
- Report installation results with actionable recommendations
- Update work-note.md with installation status

## Workflow Expectation

**Default Behavior**: Executes installation autonomously, waits for completion, analyzes results.

**Stop Conditions**:
- Installation succeeds (report success)
- Installation fails (analyze logs, report errors)

**Prompt Forwarding**:
- If installation succeeds: User may proceed to `/review-port` for validation
- If installation fails: User may need to fix port files, then retry `/install-port`

## User Input

Extract installation request from natural language input:

**Supported Patterns**:
- Port names: `openssl3`, `tensorflow-lite`
- With features: `opencv4[opengl,ffmpeg]`
- With triplet: `zlib-ng:x64-windows`, `cpuinfo:arm64-android`
- Multiple ports: `openssl3 zlib-ng cpuinfo`
- Test with editable: `install openssl3 --editable` (for development)

**Examples**:
```
Install openssl3
Test cpuinfo port installation
Install opencv4[opengl] with x64-windows triplet
```

## Process

### Phase 1: Parse Installation Request

#### Step 1.1: Analyze user input
- Tool: Internal parsing
- Extract: Port names, features, triplet, editable flag

#### Step 1.2: Determine port location
- Check: Port exists in `ports/{port-name}/`
- Tool: `#fileSearch`
- Pattern: `ports/{port-name}/vcpkg.json`
- Purpose: Verify port is in local registry

#### Step 1.3: Validate triplet
- Condition: Custom triplet requested
- Check: Triplet file exists in `triplets/{triplet}.cmake`
- Fallback: Use default host triplet (x64-windows, x64-linux, arm64-osx)

#### Step 1.4: Check for features
- Tool: `#readFile`
- File: `ports/{port-name}/vcpkg.json`
- Purpose: Verify requested features exist in port manifest

### Phase 2: Pre-Installation Checks

#### Step 2.1: Verify VCPKG_ROOT environment variable
- Tool: `#runInTerminal`
- Command (PowerShell): `echo $env:VCPKG_ROOT`
- Command (Bash/Zsh): `echo $VCPKG_ROOT`
- Purpose: Ensure vcpkg installation accessible

#### Step 2.2: Check vcpkg version
- Tool: `#runInTerminal`
- Command: `vcpkg version`
- Purpose: Report vcpkg version for debugging

#### Step 2.3: Clean previous install (optional)
- Condition: User requested fresh install
- Tool: `#runInTerminal`
- Command (PowerShell): `Remove-Item -Recurse -Force "packages/{port-name}_*"`
- Command (Bash/Zsh): `rm -rf packages/{port-name}_*`
- Purpose: Remove cached packages

### Phase 3: Execute Installation

#### Step 3.1: Construct vcpkg install command
- Base command: `vcpkg install`
- Add: `--overlay-ports ./ports`
- Add (if custom triplet): `--overlay-triplets ./triplets --triplet {triplet}`
- Add (if editable): `--editable`
- Add (if custom roots): `--x-buildtrees-root buildtrees --x-packages-root packages --x-install-root installed`
- Add: Port specification with features

#### Step 3.2: Run vcpkg install
- Tool: `#runInTerminal`
- Command (example PowerShell):
  ```powershell
  vcpkg install --overlay-ports ./ports `
    --x-buildtrees-root buildtrees `
    --x-packages-root packages `
    --x-install-root installed `
    openssl3
  ```
- Command (example Bash/Zsh):
  ```bash
  vcpkg install --overlay-ports ./ports \
    --x-buildtrees-root buildtrees \
    --x-packages-root packages \
    --x-install-root installed \
    openssl3
  ```
- Wait: Installation completion (can take several minutes)

#### Step 3.3: Capture terminal output
- Tool: `#terminalLastCommand`
- Purpose: Get full installation log

### Phase 4: Analyze Results

#### Step 4.1: Check installation exit code
- Success: Exit code 0
- Failure: Non-zero exit code

#### Step 4.2: Parse installation output (if success)
- Search for: `Package openssl3:x64-windows is successfully installed`
- Extract: Installation time, dependencies built

#### Step 4.3: Analyze build logs (if failure)
- Tool: `#readFile`
- Files (check in order):
  1. `buildtrees/{port-name}/config-{triplet}-out.log`
  2. `buildtrees/{port-name}/install-{triplet}-out.log`
  3. `buildtrees/{port-name}/build-{triplet}-out.log`
- Search for: Error patterns (CMake errors, compiler errors, linker errors)

#### Step 4.4: Identify common error patterns
- CMake configuration errors: `CMake Error`, `Could NOT find`
- Compiler errors: `error C2XXX`, `error: ...`
- Linker errors: `unresolved external symbol`, `undefined reference`
- Missing dependencies: `Package ... is not installed`

#### Step 4.5: Extract error context
- Tool: `#readFile`
- Read: 20 lines before and after first error
- Purpose: Provide diagnostic context

### Phase 5: Post-Installation Verification (if success)

#### Step 5.1: Check installed files
- Tool: `#fileSearch`
- Pattern: `packages/{port-name}_*/` or `installed/{triplet}/`
- Purpose: Verify installation artifacts exist

#### Step 5.2: List installed headers
- Tool: `#runInTerminal`
- Command (PowerShell): `Get-ChildItem "installed/{triplet}/include/{port-name}*" -Recurse`
- Command (Bash/Zsh): `ls -R installed/{triplet}/include/{port-name}*`
- Purpose: Confirm header files installed

#### Step 5.3: List installed libraries
- Tool: `#runInTerminal`
- Command (PowerShell): `Get-ChildItem "installed/{triplet}/lib/*.lib"`
- Command (Bash/Zsh): `ls installed/{triplet}/lib/*.{a,so,dylib}`
- Purpose: Confirm library files built

#### Step 5.4: Check usage file
- Tool: `#readFile`
- File: `ports/{port-name}/usage`
- Purpose: Include usage instructions in report (if available)

### Phase 6: Generate Report

#### Step 6.1: Compile installation summary
- Status: Success or failure
- Duration: Installation time
- Errors: Error messages (if failed)
- Next steps: Recommendations

#### Step 6.2: Update work-note.md
- Tool: `#editFiles` (append mode)
- Content: Installation result with timestamp

## Reporting

### Successful Installation

```markdown
# Port Installation Report

**Port**: `openssl3`
**Triplet**: x64-windows
**Date**: 2025-11-26 12:05:30

## Installation Result

✅ **Success**

### Details

- **Duration**: 2m 45s
- **Dependencies Built**: 2 (vcpkg-cmake, vcpkg-cmake-config)
- **Output Location**: `installed/x64-windows/`

### Installed Files

**Headers**: 
- `installed/x64-windows/include/openssl/*.h` (285 files)

**Libraries**:
- `installed/x64-windows/lib/libssl.lib`
- `installed/x64-windows/lib/libcrypto.lib`

**Binaries**:
- `installed/x64-windows/bin/libssl-3-x64.dll`
- `installed/x64-windows/bin/libcrypto-3-x64.dll`

### Usage

```cmake
find_package(OpenSSL REQUIRED)
target_link_libraries(main PRIVATE OpenSSL::SSL OpenSSL::Crypto)
```

## Command Used

```powershell
vcpkg install --overlay-ports ./ports `
  --x-buildtrees-root buildtrees `
  --x-packages-root packages `
  --x-install-root installed `
  openssl3:x64-windows
```

## Next Steps

Port installed successfully. Consider:
1. Review port with `/review-port openssl3` to validate against guidelines
2. Add version to registry: `./scripts/registry-add-version.ps1 -PortName "openssl3"`
```

### Installation with Features

```markdown
# Port Installation Report

**Port**: `opencv4[opengl,ffmpeg]`
**Triplet**: x64-windows
**Date**: 2025-11-26 12:10:15

## Installation Result

✅ **Success**

### Features Enabled

- ✅ `opengl` - OpenGL support
- ✅ `ffmpeg` - FFmpeg video codec support

### Details

- **Duration**: 15m 32s
- **Dependencies Built**: 18 (including ffmpeg, opengl, vcpkg-cmake, ...)
- **Output Location**: `installed/x64-windows/`

### Installed Files

**Headers**: 
- `installed/x64-windows/include/opencv4/opencv2/*.hpp` (450+ files)

**Libraries**:
- `installed/x64-windows/lib/opencv_core4.lib`
- `installed/x64-windows/lib/opencv_videoio4.lib` (with ffmpeg)
- `installed/x64-windows/lib/opencv_highgui4.lib` (with opengl)
- ... (12 total)

## Command Used

```powershell
vcpkg install --overlay-ports ./ports `
  --x-buildtrees-root buildtrees `
  --x-packages-root packages `
  --x-install-root installed `
  "opencv4[opengl,ffmpeg]:x64-windows"
```
```

### Installation Failed - CMake Configuration Error

```markdown
# Port Installation Report

**Port**: `tensorflow-lite`
**Triplet**: x64-windows
**Date**: 2025-11-26 12:15:45

## Installation Result

❌ **Failed**

### Error Summary

CMake configuration failed - could not find Abseil libraries

### Error Details

```
CMake Error at CMakeLists.txt:42 (find_package):
  Could not find a package configuration file provided by "absl" with any
  of the following names:

    abslConfig.cmake
    absl-config.cmake

  Add the installation prefix of "absl" to CMAKE_PREFIX_PATH or set
  "absl_DIR" to a directory containing one of the above files.
```

### Log Location

`buildtrees/tensorflow-lite/config-x64-windows-out.log` (lines 245-260)

## Diagnosis

⚠️ **Missing Dependency**: `abseil` package

### Root Cause

Port manifest (`ports/tensorflow-lite/vcpkg.json`) does not list `abseil` as a dependency, but CMake requires it.

### Recommended Fix

1. Edit `ports/tensorflow-lite/vcpkg.json`
2. Add `abseil` to dependencies array:
   ```json
   {
     "name": "tensorflow-lite",
     "version": "2.14.0",
     "dependencies": [
       "abseil",
       "flatbuffers",
       "vcpkg-cmake",
       "vcpkg-cmake-config"
     ]
   }
   ```

3. Retry installation:
   ```powershell
   /install-port tensorflow-lite
   ```

## Command Used

```powershell
vcpkg install --overlay-ports ./ports `
  --x-buildtrees-root buildtrees `
  --x-packages-root packages `
  --x-install-root installed `
  tensorflow-lite:x64-windows
```
```

### Installation Failed - Compiler Error

```markdown
# Port Installation Report

**Port**: `cpuinfo`
**Triplet**: x64-windows
**Date**: 2025-11-26 12:20:30

## Installation Result

❌ **Failed**

### Error Summary

MSVC compilation error - undefined identifier

### Error Details

```
C:\...\cpuinfo\src\x86\cache\init.c(42): error C2065: 'CPUINFO_LOG_ERROR': undeclared identifier
C:\...\cpuinfo\src\x86\cache\init.c(42): error C3861: 'CPUINFO_LOG_ERROR': identifier not found
```

### Log Location

`buildtrees/cpuinfo/build-x64-windows-out.log` (lines 1250-1255)

## Diagnosis

⚠️ **Build Configuration Issue**: Logging macros not defined

### Root Cause

Port needs to enable logging feature or define `CPUINFO_LOG_ERROR` macro

### Recommended Fixes

**Option 1**: Add CMake definition in portfile.cmake
```cmake
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DCPUINFO_BUILD_TOOLS=OFF
        -DCPUINFO_LOG_LEVEL=error
)
```

**Option 2**: Create patch to fix upstream code
```cmake
vcpkg_apply_patches(
    SOURCE_PATH "${SOURCE_PATH}"
    PATCHES
        fix-logging-macros.patch
)
```

### Next Steps

1. Update `ports/cpuinfo/portfile.cmake` with fix
2. Retry installation: `/install-port cpuinfo`

## Command Used

```powershell
vcpkg install --overlay-ports ./ports `
  --x-buildtrees-root buildtrees `
  --x-packages-root packages `
  --x-install-root installed `
  cpuinfo:x64-windows
```
```

### Installation Failed - Missing Patch

```markdown
# Port Installation Report

**Port**: `openssl3`
**Triplet**: arm64-android
**Date**: 2025-11-26 12:25:10

## Installation Result

❌ **Failed**

### Error Summary

Build system error - Android-specific configuration not found

### Error Details

```
Operating system: Android
This system is not supported, see NOTES-ANDROID.md for details
CMake Error at CMakeLists.txt:12 (message):
  Android builds require ANDROID_NDK_HOME
```

### Log Location

`buildtrees/openssl3/config-arm64-android-out.log` (lines 20-30)

## Diagnosis

⚠️ **Platform-Specific Issue**: Android triplet requires special handling

### Root Cause

Port portfile.cmake does not set Android-specific variables for OpenSSL build

### Recommended Fix

Update `ports/openssl3/portfile.cmake`:

```cmake
if(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "Android")
    list(APPEND CONFIGURE_OPTIONS
        "ANDROID_NDK_HOME=$ENV{ANDROID_NDK_HOME}"
        "ANDROID_PLATFORM=android-${VCPKG_CMAKE_SYSTEM_VERSION}"
    )
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS ${CONFIGURE_OPTIONS}
)
```

### Alternative: Create Android-Specific Patch

Create `ports/openssl3/android-ndk.patch` with NDK detection fixes

### Next Steps

1. Update portfile.cmake with Android support
2. Ensure `ANDROID_NDK_HOME` environment variable is set
3. Retry: `/install-port openssl3:arm64-android`

## Command Used

```powershell
vcpkg install --overlay-ports ./ports `
  --overlay-triplets ./triplets `
  --triplet arm64-android `
  --x-buildtrees-root buildtrees `
  --x-packages-root packages `
  --x-install-root installed `
  openssl3
```
```

## Work Note Entry

### Success

```markdown
## 2025-11-26 12:05:30 - /install-port

✅ Installation successful
- Port: openssl3:x64-windows
- Duration: 2m 45s
- Dependencies: 2 built
- Output: installed/x64-windows/
- Next: Review port with /review-port
```

### Failure

```markdown
## 2025-11-26 12:15:45 - /install-port

❌ Installation failed
- Port: tensorflow-lite:x64-windows
- Error: Missing dependency (abseil)
- Log: buildtrees/tensorflow-lite/config-x64-windows-out.log
- Fix: Add abseil to vcpkg.json dependencies
- Retry: After fixing dependencies
```
