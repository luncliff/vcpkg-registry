---
description: 'Create a new vcpkg port with portfile.cmake, vcpkg.json, and patches'
agent: 'agent'
tools: ['edit/createFile', 'edit/createDirectory', 'edit/editFiles', 'search/fileSearch', 'search/readFile', 'runCommands/runInTerminal', 'fetch', 'githubRepo']
model: Claude Haiku 4.5 (copilot)
---

# Create Port

Generate a new vcpkg port from scratch using project information, existing port templates, and automated checksum calculation.

## Prompt Goals

- Gather comprehensive project information (name, version, license, dependencies)
- Find similar ports to use as templates
- Calculate SHA512 checksums for source archives
- Generate `portfile.cmake` with proper `vcpkg_from_github` or `vcpkg_download_distfile` calls
- Generate `vcpkg.json` with correct metadata
- Create patches if needed
- Follow vcpkg porting best practices

## Workflow Expectation

**Default Behavior**: Autonomously gathers information, generates port files, and validates structure. Does NOT execute installation test automatically.

**Stop Conditions**:
- Port files created and validated
- User instructed to test with `/install-port`

**Prompt Forwarding**: Always forward to `/install-port` for testing after creation

## User Input

Extract project information from natural language input:

**Supported Patterns**:
- GitHub URLs: `https://github.com/owner/repo`
- Project names with hints: `create port for cpuinfo from pytorch`
- Version specifications: `openssl version 3.0.15`
- Local path references: `port from C:/projects/mylib`

**Examples**:
```
Create port for https://github.com/pytorch/cpuinfo
Add port for openssl3 version 3.0.15
Generate port files for farmhash
```

## Process

### Phase 1: Gather Project Information

#### Step 1.1: Analyze user input
- Tool: Internal parsing
- Extract: GitHub URL, project name, version hint

#### Step 1.2: Fetch project repository information
- Condition: GitHub URL provided
- Tool: #tool:fetch
- URL: GitHub repository API or raw README
- Purpose: Get project description, license, homepage

#### Step 1.3: Fetch latest release
- Tool: #tool:fetch
- URL: `{github-url}/releases/latest` or `{github-url}/tags`
- Purpose: Get latest version number and release URL
- Fallback: Use commit SHA if no releases

#### Step 1.4: Identify build system
- Tool: #tool:fetch
- Files to check: `CMakeLists.txt`, `meson.build`, `configure.ac`, `Makefile`, `*.pro`
- Purpose: Determine build system type
- Note: CMake is most common and preferred

#### Step 1.5: Check for vcpkg port in upstream
- Tool: #tool:githubRepo
- Repo: `microsoft/vcpkg`
- Query: `path:ports/{port-name} filename:vcpkg.json`
- Purpose: Check if port already exists upstream (avoid duplication)

#### Step 1.6: Identify dependencies
- Tool: #tool:fetch or #tool:search/readFile
- Files: `README.md`, `INSTALL.md`, `CMakeLists.txt`, `find_package` calls
- Purpose: List required dependencies
- Note: Map to vcpkg port names (e.g., `zlib` → `zlib-ng` if preferred)

#### Step 1.7: Determine port name
- Rule: Use lowercase, hyphen-separated
- Examples: `openssl3`, `zlib-ng`, `tensorflow-lite`
- Avoid: Uppercase, underscores, version numbers in name
- Check: Run `vcpkg search {port-name}` to avoid conflicts

### Phase 2: Find Template Ports

#### Step 2.1: Search for similar ports
- Tool: #tool:search/fileSearch
- Pattern: `ports/**/portfile.cmake`
- Criteria: Same build system, similar project size
- Priority: Ports with clean, well-documented portfiles

#### Step 2.2: Read template portfile.cmake
- Tool: #tool:search/readFile
- Files: 2-3 similar port portfiles
- Purpose: Understand common patterns and functions

#### Step 2.3: Read template vcpkg.json
- Tool: #tool:search/readFile
- Files: Corresponding vcpkg.json files
- Purpose: Understand metadata structure

### Phase 3: Calculate SHA512 Checksums

#### Step 3.1: Download source archive
- Tool: #tool:runCommands/runInTerminal
- Command (PowerShell): 
  ```powershell
  $Version = "{version}"
  $Url = "{source-url}"
  curl -L -o "temp-${Version}.tar.gz" $Url
  ```
- Purpose: Get source archive for checksum calculation

#### Step 3.2: Calculate SHA512
- Tool: #tool:runCommands/runInTerminal
- Command (PowerShell):
  ```powershell
  (Get-FileHash -Algorithm SHA512 "temp-${Version}.tar.gz").Hash.ToLower()
  ```
- Command (Bash/Zsh):
  ```bash
  sha512sum "temp-${version}.tar.gz" | awk '{print $1}'
  ```
- Purpose: Generate SHA512 for `vcpkg_from_github` or `vcpkg_download_distfile`

#### Step 3.3: Clean up downloaded archive
- Tool: #tool:runCommands/runInTerminal
- Command (PowerShell): `Remove-Item "temp-${Version}.tar.gz"`
- Command (Bash/Zsh): `rm "temp-${version}.tar.gz"`

### Phase 4: Generate Port Files

#### Step 4.1: Create port directory
- Tool: #tool:edit/createDirectory
- Path: `ports/{port-name}/`

#### Step 4.2: Generate vcpkg.json
- Tool: #tool:edit/createFile
- File: `ports/{port-name}/vcpkg.json`
- Note: Add project dependencies to array

Content template:
```json
{
  "name": "{port-name}",
  "version": "{version}",
  "description": "{project-description}",
  "homepage": "{project-url}",
  "license": "{license-spdx-id}",
  "dependencies": [
    { "name": "vcpkg-cmake", "host": true },
    { "name": "vcpkg-cmake-config", "host": true }
  ]
}
```

#### Step 4.3: Generate portfile.cmake
- Tool: #tool:edit/createFile
- File: `ports/{port-name}/portfile.cmake`

Content template (for GitHub projects with CMake):  

```cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO {owner}/{repo}
    REF v${VERSION}
    SHA512 {calculated-sha512}
    HEAD_REF {main-branch}
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
      ${FEATURE_OPTIONS} # placeholder for feature-specific options
      -DBUILD_TESTING=OFF # No tests, benchmarks, examples(samples)
      -DBUILD_BENCHMARKS=OFF
      -DBUILD_EXAMPLES=OFF
      -DBUILD_SAMPLES=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME {package-name})

file(REMOVE_RECURSE
  "${CURRENT_PACKAGES_DIR}/debug/include" # include files are same with release
  "${CURRENT_PACKAGES_DIR}/debug/share"   # vcpkg_*_fixup relocated the debug/release shared files
)

# Install copyright files. The file name varies: LICENSE.txt, COPYING, etc.
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
```

#### Step 4.4: Create usage file (optional)
- Condition: Port provides CMake config or pkg-config
- Tool: #tool:edit/createFile
- File: `ports/{port-name}/usage`

Typically we don't have to create a usage file for header-only libraries without config targets.  
If created, describe the usage example with CMake command `find_package`(CMake config files), `find_library`(library path), and `find_path`(header include directory):

```markdown
{port-name} provides CMake targets:

    find_package({PackageName} CONFIG REQUIRED)
    target_link_libraries(main PRIVATE {namespace}::{target})
```

#### Step 4.5: Document special build requirements
- Condition: Port requires patches or custom build steps
- Action: Add comments to portfile.cmake explaining rationale
- Comment:
   - Some projects may use the GitHub Actions build workflows.
   - Reference the files in `${SOURCE_PATH}/.github/workflows` folder in builtrees, so the reviewer can recognize the build step differences.

### Phase 5: Validate Port Structure

#### Step 5.1: Check required files exist
- Tool: #tool:search/fileSearch
- Files: `vcpkg.json`, `portfile.cmake`
- Purpose: Ensure mandatory files created

#### Step 5.2: Run vcpkg format-manifest
- Tool: #tool:runCommands/runInTerminal
- Purpose: Format vcpkg.json according to vcpkg standards

```powershell
./scripts/registry-format.ps1 -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
```

#### Step 5.3: Validate vcpkg.json schema
- Tool: #tool:search/readFile
- File: `ports/{port-name}/vcpkg.json`
- Check: Required fields (name, version, description)
- Check: Version format (no leading 'v', use semver or date)

#### Step 5.4: Validate portfile.cmake syntax
- Tool: #tool:search/readFile
- File: `ports/{port-name}/portfile.cmake`
- Check: Uses vcpkg helper functions
- Check: Proper SHA512 format (128 hex characters, lowercase)
- Check: HEAD_REF specified for vcpkg_from_github

### Phase 6: Generate Report and Next Steps

#### Step 6.1: Compile port creation summary
- List: Created files, detected build system, calculated checksums
- Format: Structured markdown

#### Step 6.2: Update work-note.md
- Tool: #tool:edit/editFiles (append mode)
- Content: Port creation details with timestamp

#### Step 6.3: Instruct user to test installation
- Forward to: `/install-port {port-name}`
- Note: Test before adding to versions

## Reporting

Replace example-based content with a deterministic specification. The agent MUST output a markdown report containing the headings below (in order). Emit all headings even if empty (use `None`). Keep bullets concise; avoid narrative paragraphs.

### Required Top-Level Headings
1. `# Port Creation Report`
2. `## Summary`
3. `## Project Metadata`
4. `## Build System Detection`
5. `## Dependencies`
6. `## Generated Files`
7. `## Checksums`
8. `## Validation`
9. `## Notes & Warnings`
10. `## Next Steps`

### 1. Summary
- Port Name: `<name>`
- Version: `<version>` (original tag form and normalized if different)
- Source: GitHub URL or homepage
- Timestamp: ISO 8601 UTC (`YYYY-MM-DD HH:MM:SS UTC`)
- Outcome: `CREATED` | `FAILED`

### 2. Project Metadata
- Description: first sentence trimmed ≤120 chars
- License: SPDX identifier (or `Unknown`)
- Latest Release/Tag: `<tag>` or `None`
- HEAD Commit (if no release): 7-char SHA or `None`

### 3. Build System Detection
- Detected: `CMake` | `Meson` | `Autotools` | `Plain` | `Unknown`
- Strategy: `vcpkg_from_github` + helper(s) chosen
- Experimental Override: `Embedded CMakeLists.txt` / `None`

### 4. Dependencies
- Direct Dependencies: list (host tools first) or `None`
- Missing Mapping: upstream names without vcpkg port matches or `None`
- Host Tools Added: e.g., `vcpkg-cmake`, `vcpkg-cmake-config`

### 5. Generated Files
Each file bullet with status icon:
- ✅ `vcpkg.json` – size bytes
- ✅ `portfile.cmake`
- ⚠️ `CMakeLists.txt` (embedded) (experimental) or `None`
- ✅ `usage` (if created) else `None`

### 6. Checksums
- Source URL: archive/tarball used
- SHA512: 128 hex chars or `placeholder (0)`
- Method: `downloaded` | `reported by vcpkg mismatch` | `placeholder`

### 7. Validation
- Manifest Fields: name/version/description/license ✅/❌
- Version Format: semver/date compliant ✅/⚠️/❌
- SHA512 Format: length + lowercase ✅/⚠️/❌
- Helper Functions Present: configure/install/fixup ✅/❌
- Debug Cleanup: include/share removal ✅/❌
- Copyright: `vcpkg_install_copyright` used ✅/⚠️/❌

### 8. Notes & Warnings
Bullets for non-blocking items:
- Embedded build script rationale
- Potential upstream duplication (if already exists in microsoft/vcpkg)
- Hardcoded REF pattern vs `${VERSION}` variable
- Placeholder checksum usage
If none: `None`

### 9. Next Steps
Ordered actionable list:
1. Test installation: `/install-port <name>`
2. (If success) Add version: `./scripts/registry-add-version.ps1 -PortName "<name>"`
3. (Optional) Create usage file if missing
4. (If experimental) Convert embedded script to patch before upstream contribution

### Post Report Action: Work Note Update

Use #tool:edit/createFile or #tool:edit/editFiles when appending to work-note.md.

```
## <timestamp UTC> - /create-port
Port: <name>
Version: <version>
Outcome: CREATED|FAILED
Checksum: <sha512|placeholder>
BuildSystem: <detected>
Experimental: yes|no
Next: /install-port <name>
```

### Failure Mode Reporting
If Outcome = FAILED, still emit sections 1–11:
- Dependencies / Generated Files / Checksums may be `None`
- Validation lists blocking missing items under Notes & Warnings
Add explicit bullet: `❌ Creation blocked: <reason>`

### Conventions
- Icons: ✅ valid, ⚠️ warning, ❌ error/blocking
- Bullet length ≤120 chars
- No full log dumps; show only required metadata
- Paths relative to workspace

### Non-Blocking Examples
- Using HEAD commit (no release) for early snapshot
- Omitted usage file for header-only without config targets

### Blocking Examples
- Missing `version` field
- Invalid SHA512 (length ≠128) unless placeholder strategy documented

This specification replaces previous illustrative examples; emit only real creation data.

### References

Documents and Guides in this repository:

- [Guide: Planning & Creating a New Port](../../docs/guide-new-port.md)
- [Guide: New Port (Build & Installation Patterns)](../../docs/guide-new-port-build.md)
- [Port Change Review Checklist](../../docs/review-checklist.md)
