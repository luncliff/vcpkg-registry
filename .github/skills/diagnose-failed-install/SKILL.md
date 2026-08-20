---
name: diagnose-failed-install
description: Analyze CMake build/install-phase log files from a vcpkg buildtree to classify compiler and linker errors. Use when a port fails during the build or install step after configure succeeds.
---

# Diagnose Failed Install

Scan `build-*-out.log`, `build-*-err.log`, `install-*-out.log`, and `install-*-err.log` files in a vcpkg buildtree to identify why the build or install step failed. Produces a structured report with error classification and a coordinator handoff recommendation.

## Goals

- PASS: Root cause of build/install failure identified, compiler/linker errors extracted, actionable recommendations provided.
- FAIL: Log files not found or unreadable; cannot determine failure reason.

## Capabilities

- Locate build and install logs for a port and triplet in `buildtrees/`
- Classify errors: compiler error, linker error, missing header, undefined symbol, ABI mismatch, out-of-memory, permission, post-build verification
- Extract error file paths, line numbers, and error codes (MSVC C-codes, GCC/Clang messages)
- Identify programming language context (C, C++, Fortran, Rust, Swift) from error patterns
- Detect platform-specific error messages (Windows, macOS, Linux)
- Count unique error and warning sites to gauge severity
- Emit machine-readable coordinator handoff

## User Input

- **Port name** (required): e.g. `tensorflow-lite`
- **Triplet** (optional): e.g. `x64-windows`; defaults to host triplet
- **Buildtrees root** (optional): defaults to `buildtrees/`

## Process

Use targeted `grep`, `head`, and `tail` commands. Do NOT read entire log files.

### Phase 1: Locate Log Files

1. List build and install logs:
   ```bash
   ls buildtrees/{port-name}/build-*-{out,err}.log \
      buildtrees/{port-name}/install-*-{out,err}.log 2>/dev/null | sort
   ```
2. Select logs for the requested triplet (or most recent).
3. Report file sizes and line counts with `wc -l`.

### Phase 2: Detect Build System and Language

1. Check for build system invocation:
   ```bash
   grep -n -m 5 -E "^(ninja|make|msbuild|cmake --build|xcodebuild|cargo build)" \
     buildtrees/{port-name}/build-{triplet}-out.log
   ```
2. Identify language from error patterns:
   - C: `error: ` in `.c` source files
   - C++: `error: ` in `.cpp`/`.cxx` files, or `std::`, `template` in messages
   - MSVC: `error C[0-9]{4}:`, `warning C[0-9]{4}:`
   - Rust: `error[E[0-9]{4}]`
   - Swift: `error: ` in `.swift` files

### Phase 3: Extract Compiler Errors

1. GCC / Clang compiler errors:
   ```bash
   grep -n -E "^[^:]+\.(c|cc|cpp|cxx|h|hpp):[0-9]+:[0-9]+: error:" \
     buildtrees/{port-name}/build-{triplet}-err.log | head -30
   ```
2. MSVC compiler errors:
   ```bash
   grep -n -E "\b[Cc][0-9]{4,5}\b|error C[0-9]{4}" \
     buildtrees/{port-name}/build-{triplet}-err.log | head -30
   ```
3. Missing header files:
   ```bash
   grep -n -E "fatal error:.*No such file|cannot open include file" \
     buildtrees/{port-name}/build-{triplet}-err.log | head -20
   ```
4. Count total compiler error lines:
   ```bash
   grep -cE ": error:" buildtrees/{port-name}/build-{triplet}-err.log || echo 0
   ```

### Phase 4: Extract Linker Errors

1. GCC / Clang linker errors:
   ```bash
   grep -n -E "undefined reference to|undefined symbol|ld: error:|ld returned [0-9]+ exit status" \
     buildtrees/{port-name}/build-{triplet}-err.log | head -30
   ```
2. MSVC linker errors:
   ```bash
   grep -n -E "LNK[0-9]{4}|unresolved external symbol|cannot open file '.*\.lib'" \
     buildtrees/{port-name}/build-{triplet}-err.log | head -30
   ```
3. Apple linker errors:
   ```bash
   grep -n -E "Undefined symbols for architecture|ld: warning: ignoring file|framework not found" \
     buildtrees/{port-name}/build-{triplet}-err.log | head -20
   ```
4. Library not found:
   ```bash
   grep -n -E "library not found for|cannot find -l" \
     buildtrees/{port-name}/build-{triplet}-err.log | head -10
   ```

### Phase 5: Extract ABI and Platform Errors

1. Architecture mismatch:
   ```bash
   grep -n -iE "(incompatible architecture|wrong ELF class|was built for|x86_64 vs arm64)" \
     buildtrees/{port-name}/build-{triplet}-err.log | head -10
   ```
2. CRT linkage mismatch (Windows):
   ```bash
   grep -n -E "DEFAULTLIB|defaultlib.*conflicts|LNK4098" \
     buildtrees/{port-name}/build-{triplet}-err.log | head -10
   ```
3. ABI version mismatch (Linux):
   ```bash
   grep -n -E "GLIBCXX_|GLIBC_[0-9]|symbol lookup error" \
     buildtrees/{port-name}/build-{triplet}-err.log | head -10
   ```

### Phase 6: Extract Install/Packaging Errors

1. CMake install errors:
   ```bash
   grep -n -E "CMake Error.*install|INSTALL.*Error|cannot install" \
     buildtrees/{port-name}/install-{triplet}-out.log \
     buildtrees/{port-name}/install-{triplet}-err.log 2>/dev/null | head -20
   ```
2. Missing output files:
   ```bash
   grep -n -E "No such file or directory|ENOENT|file INSTALL cannot find" \
     buildtrees/{port-name}/install-{triplet}-err.log 2>/dev/null | head -10
   ```
3. Permission errors:
   ```bash
   grep -n -iE "(permission denied|access is denied|EPERM|EACCES)" \
     buildtrees/{port-name}/install-{triplet}-err.log 2>/dev/null | head -10
   ```

### Phase 7: Classify Root Cause

Apply the first matching rule:

| Class | Pattern |
|-------|---------|
| `COMPILER_ERROR` | `: error:` or `error C[0-9]+` found in build log |
| `LINKER_ERROR` | `undefined reference`, `LNK[0-9]+`, `undefined symbol` |
| `MISSING_HEADER` | `No such file or directory` in include |
| `ABI_MISMATCH` | Architecture or CRT mismatch patterns |
| `INSTALL_ERROR` | `file INSTALL cannot find`, `ENOENT` in install log |
| `PERMISSION_ERROR` | `permission denied`, `EACCES` |
| `BUILD_SYSTEM_ERROR` | Build tool non-zero exit without matching pattern above |
| `UNKNOWN` | No pattern matched |

## Reporting

Output a markdown report with these headings (in order). Emit all headings even if empty (use `None`).

1. `# Build/Install Failure Diagnostics`
2. `## Summary` — Port, triplet, timestamp, outcome (ROOT_CAUSE_FOUND / INCONCLUSIVE)
3. `## Log Files` — Paths checked, file sizes, line counts
4. `## Build System` — Tool (Ninja/Make/MSBuild/Xcode), language(s) detected
5. `## Compiler Errors` — Error class, first 5 error lines with path:line:col, total count
6. `## Linker Errors` — Error class, first 5 error lines with symbol names, total count
7. `## ABI / Platform Errors` — Architecture, CRT linkage, GLIBC issues
8. `## Install Errors` — CMake install phase errors, missing files, permission issues
9. `## Warnings Summary` — Warning count, top 3 recurring warning types
10. `## Root Cause` — Classification label, supporting evidence (log path:line)
11. `## Recommendations` — Specific fixes ordered by priority
12. `## Coordinator Handoff` — Machine-readable one-line: `NEXT_SKILL: <skill-name> | REASON: <short reason>`

### Coordinator Handoff Rules

| Root Cause Class | Suggested Next Skill |
|-----------------|---------------------|
| `MISSING_HEADER` | `diagnose-failed-dependency` |
| `LINKER_ERROR` | `diagnose-failed-dependency` |
| `ABI_MISMATCH` | `review-port` |
| `COMPILER_ERROR` | `review-port` |
| `INSTALL_ERROR` | `review-port` |
| `PERMISSION_ERROR` | `check-environment` |
| `UNKNOWN` | `review-port` |

### Conventions
- Icons: ✅ ok, ❌ error, ⚠️ warning
- Cite log path and line number for every finding
- Quote only relevant lines (max 5 lines per finding)
- Trim lists >10 items with `... (+N more)`
- All paths relative to workspace root
