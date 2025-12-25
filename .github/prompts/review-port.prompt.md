---
description: 'Review port files against vcpkg guidelines and best practices'
agent: 'agent'
tools: ['read/readFile', 'edit/createFile', 'edit/editFiles', 'search/fileSearch', 'search/textSearch', 'web/fetch', 'todo']
model: Claude Sonnet 4 (copilot)
---

# Review Port

Validate port files (vcpkg.json, portfile.cmake, patches, usage) against vcpkg contribution guidelines and registry best practices.

## Prompt Goals

- PASS: Port satisfies all mandatory checklist items; ready for PR and version baseline update.
- FAIL: List of failing checks with recommended fixes; port needs corrections.

**Additional Goals**:
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
- If review passes: User may proceed to add version (`./scripts/registry-add-version.ps1` or `/update-version-baseline`)
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
- Tool: #tool:search/fileSearch
- Pattern: `ports/{port-name}/vcpkg.json`
- Purpose: Verify port exists

#### Step 1.2: List all port files
- Tool: #tool:search/fileSearch
- Pattern: `ports/{port-name}/**/*`
- Purpose: Get complete file inventory

#### Step 1.3: Identify file types
- Categorize: `vcpkg.json`, `portfile.cmake`, `*.patch`, `usage`, `copyright`, `CMakeLists.txt`, others
- Purpose: Determine which files need review

### Phase 2: Fetch vcpkg Guidelines

#### Step 2.1: Fetch contribution guidelines
- Tool: #tool:web/fetch
- URL: [microsoft/vcpkg Contribution Guide](https://github.com/microsoft/vcpkg/blob/master/CONTRIBUTING.md)
- Purpose: Get latest contribution requirements

#### Step 2.2: Fetch maintainer guide
- Tool: #tool:web/fetch
- URL: [microsoft/vcpkg-docs Maintainer guide](https://github.com/microsoft/vcpkg-docs/blob/main/vcpkg/contributing/maintainer-guide.md)
- Purpose: Get port maintenance best practices

#### Step 2.3: Load local review checklist
- Tool: #tool:read/readFile
- File: `docs/review-checklist.md`
- Purpose: Apply repository-specific checks

#### Step 2.4: Load local copilot instructions
- Tool: #tool:read/readFile
- File: `.github/copilot-instructions.md`
- Purpose: Check for experimental guidelines (embedded CMakeLists.txt, patches)

### Phase 3: Validate vcpkg.json

#### Step 3.1: Read vcpkg.json
- Tool: #tool:read/readFile
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
- Tool: #tool:read/readFile
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
- Tool: #tool:search/fileSearch
- Pattern: `ports/{port-name}/usage`
- Recommended: If port provides CMake config or pkg-config

#### Step 5.2: Read usage file (if exists)
- Tool: #tool:read/readFile
- File: `ports/{port-name}/usage`
- Validate: Provides clear `find_package` and `target_link_libraries` example

#### Step 5.3: Check for embedded CMakeLists.txt
- Tool: #tool:search/fileSearch
- Pattern: `ports/{port-name}/CMakeLists.txt`
- Warning: Experimental approach, document rationale

#### Step 5.4: Validate patch files (if exist)
- Tool: #tool:read/readFile
- Files: `ports/{port-name}/*.patch`
- Check: Patches have descriptive names
- Check: Patch context explains purpose (comments in portfile.cmake)

#### Step 5.5: Check for unnecessary files
- Avoid: Binary files, large test data, generated files
- Avoid: Duplicate documentation (prefer upstream README)

### Phase 6: Cross-Reference with Baseline

#### Step 6.1: Check versions baseline
- Tool: #tool:read/readFile
- File: `versions/baseline.json`
- Validate: Port listed in baseline

#### Step 6.2: Check version history
- Tool: #tool:read/readFile
- File: `versions/{first-letter}-/{port-name}.json`
- Validate: Version history exists (if port previously added)

### Phase 7: Generate Review Report

#### Step 7.1: Compile validation results
- Categorize: Critical issues, warnings, suggestions
- Format: Structured markdown with pass/fail sections

## Reporting

Replace example-filled output with a structured, deterministic report. The agent MUST emit a markdown document with the following top-level headings (in order) and required subsections. Each heading must be present even if the section is empty; write `None` for empty content. Avoid embellishment; focus on factual validation results.

### Required Headings
1. `# Port Review Report` (title)
2. `## Summary`
3. `## File Inventory`
4. `## vcpkg.json Validation`
5. `## portfile.cmake Validation`
6. `## Additional Files`
7. `## Baseline Check`
8. `## Issues Summary`
9. `## Recommendations`
10. `## Next Steps`

### 1. Summary
- Port: `<name>`
- Date: `<UTC timestamp>`
- Overall Result: `PASS` | `PASS (experimental)` | `FAIL`
- Experimental Notes: present only if embedded CMakeLists.txt or non-standard approach detected

### 2. File Inventory
List each relevant file with status icon:
- ✅ present and valid
- ⚠️ present with warnings
- ❌ missing or invalid
Include: `vcpkg.json`, `portfile.cmake`, `usage`, patch files (`*.patch`), embedded `CMakeLists.txt`, license/copyright artifacts, auxiliary build scripts.

### 3. vcpkg.json Validation
Subsections (always emit):
- Required Fields: enumerate `name`, `version*|version-date|version-semver`, `description`
- Optional Fields: `homepage`, `license`, `supports`, `features`
- Version Format: note schema compliance, tag stripping, absence of leading `v`
- Dependencies: list each with host/tool flags correctness
- Features: list or `None`; validate naming & dependency chains
Each item annotated with ✅/⚠️/❌ and concise rationale for non-✅.

### 4. portfile.cmake Validation
Subsections:
- Source Acquisition: method used, REF strategy, SHA512 length/format, HEAD_REF presence
- Build Helpers: usage of official helper functions (configure/install/fixup)
- Installation Cleanup: removal of debug artifacts (`debug/include`, `debug/share`)
- Patch Handling: PATCHES argument or `vcpkg_apply_patches` usage
- Copyright: use of `vcpkg_install_copyright`
- Deprecated Usage: list deprecated functions if found or `None`

### 5. Additional Files
Report on:
- `usage` file: presence & clarity (find_package + target_link_libraries)
- Embedded `CMakeLists.txt`: experimental note + upstream conversion reminder
- Patch Files: list each with brief purpose (derived from filename or comments)
- Unnecessary Files: binaries/large assets; list or `None`

### 6. Baseline Check
- Baseline Entry: present/missing
- Version History File: path and presence
- Latest Version Match: whether `vcpkg.json` version matches top entry

### 7. Issues Summary
Split into:
- Critical Issues: must fix before PASS (blocking schema errors, missing version, invalid SHA512, absent source acquisition, baseline absence when required)
- Warnings: recommended improvements (missing optional fields, uppercase SHA512, lack of usage file, deprecated helper usage)
Enumerate each with short actionable fix snippet (JSON/CMake line).

### 8. Recommendations
High-level improvement suggestions (e.g., "Add usage file", "Convert embedded CMakeLists.txt to patch for upstream"). If none, state `None`.

### 9. Next Steps
Branch based:
- PASS: suggest optional actions (add version if updated, run install test)
- PASS (experimental): include upstream conversion reminder
- FAIL: ordered list: fix critical issues → re-run review.

### Severity Classification Rules
- Critical: Violates schema, prevents reproducible build, or breaks registry versioning
- Warning: Quality / guideline deviation but build likely succeeds
- Recommendation: Non-mandatory enhancement, stylistic or future-proofing

### Output Conventions
- Use consistent emoji indicators ✅/⚠️/❌
- Prefer bullet lists; avoid tables unless multiple patches (>3)
- Keep code snippets minimal (single line) unless clarity demands more
- Timestamp in ISO 8601 UTC (`YYYY-MM-DD HH:MM:SS UTC`)

### Multi-Port Review
If multiple ports requested, produce one consolidated document with a `## Port: <name>` block repeating sections 2–7 per port, then a global Issues Summary / Recommendations / Next Steps.

### Non-Blocking Omissions
If a port intentionally omits a `usage` file (no exported targets), mark usage as `None (library has no CMake config)` not as a warning.

### SHA512 Validation Rule
Length must be 128 hex chars; case-insensitive match permitted but flag uppercase as warning.

This specification replaces prior illustrative examples. Do not embed sample reports—emit only live analysis per execution.

### References

Documents and Guides in this repository:

- [Guide: Updating an Existing Port](../../docs/guide-update-port.md)
- [Port Change Review Checklist](../../docs/review-checklist.md)
