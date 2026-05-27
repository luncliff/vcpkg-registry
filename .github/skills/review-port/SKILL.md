---
name: review-port
description: Review port files against vcpkg guidelines and best practices. Use when asked to review, validate, or check a port for correctness.
---

# Review Port

Validate port files (vcpkg.json, portfile.cmake, patches, usage) against vcpkg contribution guidelines and registry best practices.

## Goals

- PASS: Port satisfies all mandatory checklist items; ready for PR and version baseline update.
- FAIL: List of failing checks with recommended fixes; port needs corrections.

## Capabilities

- Locate and read all port files
- Fetch vcpkg contribution guidelines and maintainer guide
- Validate vcpkg.json structure (schema compliance, version format, dependencies)
- Validate portfile.cmake (helper function usage, SHA512 format, copyright handling)
- Check for required files (usage, copyright notice)
- Identify violations and suggest corrections
- Generate comprehensive review report

## User Input

**Supported Patterns**:
- Port names: `openssl3`, `tensorflow-lite`
- With path: `review ports/openssl3`
- Batch review: `review openssl3 zlib-ng cpuinfo`

## Process

### Phase 1: Locate Port Files

1. Find port directory: `ports/{port-name}/vcpkg.json`
2. List all port files: `ports/{port-name}/**/*`
3. Categorize: `vcpkg.json`, `portfile.cmake`, `*.patch`, `usage`, `copyright`, `CMakeLists.txt`, others

### Phase 2: Fetch vcpkg Guidelines

1. Fetch contribution guidelines from microsoft/vcpkg
2. Fetch maintainer guide from microsoft/vcpkg-docs
3. Load local `docs/review-checklist.md`

### Phase 3: Validate vcpkg.json

1. Check required fields: `name`, `version`, `description`
2. Check optional fields: `homepage`, `license`, `supports`
3. Validate version format: no leading 'v', valid semver or date format
4. Validate dependencies: exist in registry/upstream, build tools use `"host"` platform
5. Validate license field: SPDX identifier format
6. Check features: naming, descriptions, dependencies

### Phase 4: Validate portfile.cmake

1. Validate source acquisition: uses `vcpkg_from_github`/`vcpkg_from_gitlab`/`vcpkg_download_distfile`
2. Check: `REF` uses `${VERSION}` variable, `SHA512` is 128 hex chars (lowercase), `HEAD_REF` specified
3. Validate build system helpers: `vcpkg_cmake_configure`, `vcpkg_cmake_install`, `vcpkg_cmake_config_fixup`
4. Validate installation: removes `debug/include` and `debug/share`
5. Validate copyright: uses `vcpkg_install_copyright(FILE_LIST ...)`
6. Check for deprecated functions: `vcpkg_fixup_cmake_targets()`, `vcpkg_copy_pdbs()`
7. Validate patches: `PATCHES` argument present, patch files exist

### Phase 5: Validate Additional Files

1. Check for `usage` file (recommended if port provides CMake config)
2. Check for embedded `CMakeLists.txt` (experimental, document rationale)
3. Validate patch files (descriptive names, purpose documented)
4. Check for unnecessary files (binaries, large test data)

### Phase 6: Cross-Reference with Baseline

1. Check `versions/baseline.json` for port entry
2. Check `versions/{first-letter}-/{port-name}.json` for version history

### Phase 7: Generate Review Report

## Reporting

Output a markdown report with these headings (in order). Emit all headings even if empty (use `None`).

1. `# Port Review Report`
2. `## Summary` — Port name, date, overall result (PASS/PASS (experimental)/FAIL)
3. `## File Inventory` — Each file with ✅/⚠️/❌ status
4. `## vcpkg.json Validation` — Required fields, optional fields, version format, dependencies, features
5. `## portfile.cmake Validation` — Source acquisition, build helpers, installation cleanup, patches, copyright, deprecated usage
6. `## Additional Files` — usage file, embedded CMakeLists.txt, patch files, unnecessary files
7. `## Baseline Check` — Baseline entry, version history file, latest version match
8. `## Issues Summary` — Critical issues (must fix) and Warnings (recommended)
9. `## Recommendations` — High-level improvement suggestions
10. `## Next Steps` — Based on PASS/FAIL status

### Severity Classification
- Critical: Violates schema, prevents reproducible build, or breaks registry versioning
- Warning: Quality/guideline deviation but build likely succeeds
- Recommendation: Non-mandatory enhancement

### Conventions
- Icons: ✅/⚠️/❌
- Keep code snippets minimal (single line)
- Timestamp in ISO 8601 UTC

### Multi-Port Review
If multiple ports requested, produce one consolidated document with `## Port: <name>` blocks.

## References

- [docs/guide-update-port.md](../../docs/guide-update-port.md)
- [docs/review-checklist.md](../../docs/review-checklist.md)
