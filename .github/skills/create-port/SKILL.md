---
name: create-port
description: Create a new vcpkg port with portfile.cmake, vcpkg.json, and patches. Use when asked to create, add, or generate a new port for a project.
---

# Create Port

Generate a new vcpkg port from scratch using project information, existing port templates, and automated checksum calculation.

## Goals

- PASS: Port files created and validated for next-step installation; structure checks passed.
- FAIL: Port creation blocked or invalid; missing critical information or template issues.

## Capabilities

- Gather comprehensive project information (name, version, license, dependencies)
- Find similar ports to use as templates
- Calculate SHA512 checksums for source archives
- Generate `portfile.cmake` with proper `vcpkg_from_github` or `vcpkg_download_distfile` calls
- Generate `vcpkg.json` with correct metadata
- Create patches if needed
- Follow vcpkg porting best practices

## User Input

**Supported Patterns**:
- GitHub URLs: `https://github.com/owner/repo`
- Project names with hints: `create port for cpuinfo from pytorch`
- Version specifications: `openssl version 3.0.15`
- Local path references: `port from C:/projects/mylib`

## Process

### Phase 1: Gather Project Information

1. Analyze user input — extract GitHub URL, project name, version hint
2. Fetch project repository information (description, license, homepage)
3. Fetch latest release (version number, release URL; fallback: commit SHA)
4. Identify build system: check for `CMakeLists.txt`, `meson.build`, `configure.ac`, `Makefile`
5. Check if port already exists in microsoft/vcpkg upstream
6. Identify dependencies from `README.md`, `CMakeLists.txt`, `find_package` calls
7. Determine port name (lowercase, hyphen-separated, no underscores or version numbers)

### Phase 2: Find Template Ports

1. Search `ports/**/portfile.cmake` for similar ports (same build system, similar size)
2. Read 2-3 similar portfile.cmake and vcpkg.json files as templates

### Phase 3: Calculate SHA512 Checksums

1. Download source archive: `curl -L -o "temp-${version}.tar.gz" $url`
2. Calculate SHA512:
   - PowerShell: `(Get-FileHash -Algorithm SHA512 "temp-${Version}.tar.gz").Hash.ToLower()`
   - Bash: `sha512sum "temp-${version}.tar.gz" | awk '{print $1}'`
3. Clean up downloaded archive

### Phase 4: Generate Port Files

1. Create `ports/{port-name}/` directory
2. Generate `vcpkg.json`:
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
3. Generate `portfile.cmake` (CMake template):
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
       ${FEATURE_OPTIONS}
       -DBUILD_TESTING=OFF
       -DBUILD_BENCHMARKS=OFF
       -DBUILD_EXAMPLES=OFF
       -DBUILD_SAMPLES=OFF
   )
   vcpkg_cmake_install()
   vcpkg_cmake_config_fixup(PACKAGE_NAME {package-name})

   file(REMOVE_RECURSE
     "${CURRENT_PACKAGES_DIR}/debug/include"
     "${CURRENT_PACKAGES_DIR}/debug/share"
   )

   vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
   ```
4. Optionally create `usage` file (for ports with CMake config targets)
5. Document special build requirements in portfile comments

### Phase 5: Validate Port Structure

1. Check required files exist (`vcpkg.json`, `portfile.cmake`)
2. Run format-manifest: `./scripts/registry-format.ps1 -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"`
3. Validate vcpkg.json schema (required fields, version format)
4. Validate portfile.cmake syntax (helper functions, SHA512 format, HEAD_REF)

### Phase 6: Generate Report and Next Steps

Forward to `install-port` skill for testing after creation.

## Reporting

Output a markdown report with these headings (in order). Emit all headings even if empty (use `None`).

1. `# Port Creation Report`
2. `## Summary` — Port name, version, source, timestamp, outcome (CREATED/FAILED)
3. `## Project Metadata` — Description, license, latest release/tag
4. `## Build System Detection` — Detected system, strategy, experimental overrides
5. `## Dependencies` — Direct dependencies, missing mappings, host tools
6. `## Generated Files` — Each file with ✅/⚠️/❌ status
7. `## Checksums` — Source URL, SHA512, method
8. `## Validation` — Manifest fields, version format, SHA512 format, helpers, cleanup, copyright
9. `## Notes & Warnings` — Non-blocking items
10. `## Next Steps` — Test with `install-port`, add version, create usage file

### Conventions
- Icons: ✅ valid, ⚠️ warning, ❌ error/blocking
- Bullet length ≤120 chars
- Paths relative to workspace

## References

- [docs/guide-create-port.md](../../docs/guide-create-port.md)
- [docs/guide-create-port-build.md](../../docs/guide-create-port-build.md)
- [docs/guide-create-port-download.md](../../docs/guide-create-port-download.md)
- [docs/review-checklist.md](../../docs/review-checklist.md)
