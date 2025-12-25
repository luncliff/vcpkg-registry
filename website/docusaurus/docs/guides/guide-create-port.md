# Guide: Create Port

This document gives the **end-to-end workflow** for creating a port in this registry. Use it as a checklist and follow the linked focused guides for deeper details.

Companion documents:
- [Source acquisition patterns](./guide-create-port-download.md)
- [Build & installation patterns](./guide-create-port-build.md)

## 1. High-Level Development Phases

### Research Phase
**Goal:** Understand upstream & requirements  
**Output:** Work notes (optional)

Research the upstream project to understand its build system, dependencies, and requirements before beginning development.

### Acquisition Draft Phase
**Goal:** Fetch source reproducibly  
**Output:** `portfile.cmake` (download section)

Create the initial source acquisition logic to download and prepare the upstream source code.

### Build Draft Phase
**Goal:** Configure/install artifacts  
**Output:** Full `portfile.cmake` implementation

Implement the complete build and installation logic for the port.

### Manifest Finalization Phase
**Goal:** Describe port metadata  
**Output:** `vcpkg.json` with version + dependencies

Create the complete port manifest with proper version information and dependency declarations.

### Test & Iterate Phase
**Goal:** Ensure clean install for target triplets  
**Output:** Working install, logs reviewed

Validate the port works correctly across target platforms and configurations.

### Version Registration Phase
**Goal:** Add to registry baseline  
**Output:** Updated `versions/*` + commit

Register the port version in the registry's version database.

---

## 2. Phase Details & Checklist

### Phase 1: Research
- Identify upstream repository URL & license.
- Determine build system (CMake, Meson, custom, binary-only).
- List runtime/build dependencies → map to existing ports via `vcpkg search`.
- Decide which platforms (triplets) you will initially validate.

Questions to answer:
- Is the project header-only? Build optional tools? Provides pkg-config or CMake configs?
- Are there bundled third-party sources that should be removed to avoid duplication?

### Phase 2: Acquisition Draft
See [Source acquisition patterns](./guide-create-port-download.md).
- Choose helper: [vcpkg_from_github](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_github) / [vcpkg_from_gitlab](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_gitlab) / [vcpkg_from_sourceforge](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_sourceforge) / [vcpkg_download_distfile](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_download_distfile).
- Use `SHA512 0` initially to obtain real hash.
- Remove vendored dependencies (if any) using `file(REMOVE_RECURSE ...)`.
- Add minimal `vcpkg.json` skeleton (name, version, description, homepage, license, tool dependencies like `vcpkg-cmake`).

### Phase 3: Build Draft
See [Build & installation patterns](./guide-create-port-build.md).
- Add build helper calls: [vcpkg_cmake_configure](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_configure) / [vcpkg_configure_meson](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_configure_meson) / relocation logic.
- Map optional features using [vcpkg_check_features](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_check_features) or Meson boolean conversion.
- Disable tests/examples unless required (`-DBUILD_TESTING=OFF`).
- Run install helpers, then fix metadata: [vcpkg_cmake_config_fixup](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_config_fixup), [vcpkg_fixup_pkgconfig](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_fixup_pkgconfig).
- Copy any executables with [vcpkg_copy_tools](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_copy_tools).

### Phase 4: Manifest Finalization
- Select one version field (`version`, `version-string`, `version-semver`, or `version-date`).
- Add feature blocks (only if they affect build inputs/outputs).
- Host-only dependencies (build tools) must include `{ "host": true }`.
- Remove unnecessary fields; keep it concise.

### Phase 5: Test & Iterate
Run overlay install to isolate from builtin ports:
```pwsh
vcpkg install --overlay-ports=ports mylib
```
Validate:
- Correct SHA512 (update if mismatch reported).
- No unexpected files in `packages/<port>` (e.g. stray `.pdb` when not on Windows).
- License file present under `share/<port>/`.
- Config files load: try a consumer CMake project or inspect `share/<port>/*.cmake` after fixup.

Optional multi-triplet checks:
```pwsh
vcpkg install --overlay-ports=ports --triplet x64-windows mylib
vcpkg install --overlay-ports=ports --triplet x64-linux   mylib
```

### Phase 6: Version Registration
Commit port before adding version entries (a clean git state is required for tooling):
```pwsh
git add ports/mylib
git commit -m "[mylib] add v1.2.3"

./scripts/registry-format.ps1 -VcpkgRoot $env:VCPKG_ROOT -RegistryRoot (Get-Location)
./scripts/registry-add-version.ps1 -PortName mylib -VcpkgRoot $env:VCPKG_ROOT -RegistryRoot (Get-Location)

git add versions
git commit -m "[mylib] version metadata v1.2.3"
```

## 3. Example Minimal Port Structure
```
ports/mylib/
  vcpkg.json
  portfile.cmake
  fix-config.patch        (optional)
```

## 4. Quality Review Checklist

Review your work with the [Contributor Checklist](./pull_request_template.md)

## 5. Troubleshooting Reference

### Common Issues and Solutions

#### Hash Mismatch
**Symptom:** Hash mismatch error during download  
**Likely Cause:** Upstream changed or wrong archive specified  
**Fix:** Recompute SHA512 hash and pin to specific commit

#### Missing CMake Config
**Symptom:** CMake configuration files not found  
**Likely Cause:** Upstream installs configuration files elsewhere  
**Fix:** Adjust `CONFIG_PATH` parameter or patch install rules

#### Duplicate Headers in Debug
**Symptom:** Header files present in both release and debug packages  
**Likely Cause:** Forgot cleanup step after installation  
**Fix:** Remove `debug/include` directory after install

#### find_package Fails
**Symptom:** CMake find_package command fails to locate the package  
**Likely Cause:** Config file paths not properly adjusted  
**Fix:** Ensure [vcpkg_cmake_config_fixup](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_config_fixup) runs with correct path

#### Meson Ignoring External Dependencies
**Symptom:** Meson build system ignores external dependencies  
**Likely Cause:** Bundled subprojects overshadow external dependencies  
**Fix:** Remove or patch `subprojects/` directory

#### Binary-Only Port Debug Validation Error
**Symptom:** Debug directory validation errors for binary-only ports  
**Likely Cause:** Debug directory is empty or missing required artifacts  
**Fix:** Remove debug directory or add required debug artifacts

## 6. Next Steps
Proceed to either:
- Deepen acquisition options → [guide-create-port-download.md](./guide-create-port-download.md)
- Tune build & packaging → [guide-create-port-build.md](./guide-create-port-build.md)

---
Happy porting!
