---
name: diagnose-failed-configure
description: Analyze CMake configure-phase log files from a vcpkg buildtree to classify errors and extract actionable diagnostics. Use when a port fails during the configure step (CMake, autoconf, meson, etc.).
---

# Diagnose Failed Configure

Scan `config-*-out.log` and `config-*-err.log` files in a vcpkg buildtree to identify why CMake configuration failed. Produces a structured report that a coordinator agent can use to decide the next fix action.

## Goals

- PASS: Root cause of configure failure identified, classified, and actionable recommendations provided.
- FAIL: Log files not found or unreadable; environment context missing.

## Capabilities

- Locate configure logs for a port and triplet in `buildtrees/`
- Classify configure errors: missing dependency, toolchain misconfiguration, SDK path, CMake policy, generator, cross-compile variable
- Extract compiler/linker detection lines and identify detected compiler identity
- Map error lines back to specific log file paths and line numbers
- Report relevant CMake cache variables (`CMAKE_*`, `VCPKG_*`) from the log
- Detect Android SDK / NDK, Apple SDK (macOS/iOS), and Windows SDK references
- Emit a machine-readable summary table for coordinator handoff

## User Input

- **Port name** (required): e.g. `openssl3`
- **Triplet** (optional): e.g. `arm64-android`; defaults to host triplet
- **Buildtrees root** (optional): defaults to `buildtrees/`

## Process

Use short, targeted shell commands with `grep`, `head`, and `tail`. Do NOT read entire log files into context.

### Phase 1: Locate Log Files

1. Resolve buildtree path: `buildtrees/{port-name}/`
2. List configure logs:
   ```bash
   ls buildtrees/{port-name}/config-*-out.log buildtrees/{port-name}/config-*-err.log 2>/dev/null
   ```
3. If no logs found: report FAIL immediately.
4. Select logs matching the requested triplet (or most recent if unspecified).

### Phase 2: Extract Compiler Detection

1. Grep for compiler identity lines:
   ```bash
   grep -n -E "^-- The (C|CXX|Fortran) compiler identification is" \
     buildtrees/{port-name}/config-{triplet}-out.log | head -10
   ```
2. Grep for compiler path:
   ```bash
   grep -n -E "CMAKE_(C|CXX)_COMPILER[= ]" \
     buildtrees/{port-name}/config-{triplet}-out.log | head -10
   ```
3. Record: compiler family (GCC/Clang/MSVC/AppleClang), version, path.

### Phase 3: Extract SDK and Toolchain Information

1. Check for Android NDK / SDK references:
   ```bash
   grep -n -iE "(ANDROID_NDK|ANDROID_SDK|android-ndk|ndk-bundle|toolchain)" \
     buildtrees/{port-name}/config-{triplet}-out.log | head -20
   ```
2. Check for Apple SDK (macOS / iOS / tvOS / watchOS):
   ```bash
   grep -n -iE "(CMAKE_OSX_SYSROOT|SDKROOT|xcrun|macosx|iphoneos|appletvos)" \
     buildtrees/{port-name}/config-{triplet}-out.log | head -20
   ```
3. Check for Windows SDK:
   ```bash
   grep -n -iE "(WindowsSDKDir|UCRTVersion|WINDOWS_SDK|CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS)" \
     buildtrees/{port-name}/config-{triplet}-out.log | head -10
   ```

### Phase 4: Extract CMake Errors

1. Primary CMake errors:
   ```bash
   grep -n "CMake Error" buildtrees/{port-name}/config-{triplet}-err.log \
     buildtrees/{port-name}/config-{triplet}-out.log | head -30
   ```
2. Find-package failures:
   ```bash
   grep -n -E "Could NOT find|No package '.*' found|find_package.*REQUIRED.*NOTFOUND" \
     buildtrees/{port-name}/config-{triplet}-out.log | head -20
   ```
3. Policy and version errors:
   ```bash
   grep -n -E "(cmake_minimum_required|CMake.*version.*required|Policy CMP[0-9]+)" \
     buildtrees/{port-name}/config-{triplet}-out.log | head -10
   ```
4. Fatal errors and call stack:
   ```bash
   grep -n -E "^CMake Error at|^ *Call Stack" \
     buildtrees/{port-name}/config-{triplet}-out.log | head -20
   ```

### Phase 5: Extract Relevant CMAKE_* Variables

1. Grep for key variables that indicate cross-compilation setup:
   ```bash
   grep -n -E "CMAKE_(SYSTEM_NAME|SYSTEM_PROCESSOR|CROSSCOMPILING|TOOLCHAIN_FILE|SYSROOT)" \
     buildtrees/{port-name}/config-{triplet}-out.log | head -20
   ```
2. Grep for VCPKG-injected variables:
   ```bash
   grep -n -E "VCPKG_(TARGET_TRIPLET|CHAINLOAD_TOOLCHAIN_FILE|CRT_LINKAGE|LIBRARY_LINKAGE)" \
     buildtrees/{port-name}/config-{triplet}-out.log | head -10
   ```

### Phase 6: Classify Root Cause

Apply the first matching rule:

| Class | Pattern |
|-------|---------|
| `MISSING_DEPENDENCY` | `Could NOT find`, `No package '...' found` |
| `TOOLCHAIN_ERROR` | `CMake Error` in a `.cmake` toolchain file |
| `COMPILER_NOT_FOUND` | `No CMAKE_C_COMPILER`, `No CMAKE_CXX_COMPILER` |
| `SDK_PATH_MISSING` | `ANDROID_NDK`, `CMAKE_OSX_SYSROOT` not found |
| `POLICY_VIOLATION` | `cmake_minimum_required`, `Policy CMP` |
| `GENERATOR_ERROR` | `CMake Error: Could not create named generator` |
| `CROSS_COMPILE_SETUP` | `CMAKE_CROSSCOMPILING` issues |
| `UNKNOWN` | No pattern matched |

## Reporting

Output a markdown report with these headings (in order). Emit all headings even if empty (use `None`).

1. `# Configure Failure Diagnostics`
2. `## Summary` — Port, triplet, timestamp, outcome (ROOT_CAUSE_FOUND / INCONCLUSIVE)
3. `## Log Files` — Paths checked, file sizes, line counts
4. `## Compiler Detection` — Family, version, path; ✅ detected / ❌ not found
5. `## SDK / Toolchain` — Android NDK, Apple SDK, Windows SDK findings
6. `## CMake Variables` — Relevant `CMAKE_*` and `VCPKG_*` values from log
7. `## Errors` — Error class, first error line (with log path and line number), total error count
8. `## Find-Package Failures` — List of packages that could not be found
9. `## Root Cause` — Classification label, supporting evidence (log path:line)
10. `## Recommendations` — Specific fixes ordered by priority
11. `## Coordinator Handoff` — Machine-readable one-line: `NEXT_SKILL: <skill-name> | REASON: <short reason>`

### Coordinator Handoff Rules

| Root Cause Class | Suggested Next Skill |
|-----------------|---------------------|
| `MISSING_DEPENDENCY` | `diagnose-failed-dependency` |
| `COMPILER_NOT_FOUND` | `check-environment` |
| `SDK_PATH_MISSING` | `check-environment` |
| `TOOLCHAIN_ERROR` | `review-port` |
| `POLICY_VIOLATION` | `review-port` |
| `CROSS_COMPILE_SETUP` | `review-port` |
| `UNKNOWN` | `review-port` |

### Conventions
- Icons: ✅ found/ok, ❌ missing/error, ⚠️ warning
- Cite exact log path and line number for every finding
- Do not dump raw log content; quote only relevant lines (max 5 lines per finding)
- Trim lists >10 items with `... (+N more)`
- All paths relative to workspace root
