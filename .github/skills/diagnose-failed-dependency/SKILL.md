---
name: diagnose-failed-dependency
description: Identify and diagnose a missing or misconfigured target-triplet dependency that is blocking a vcpkg port build. Use when configure or build fails due to a missing library, header, or find_package failure.
---

# Diagnose Failed Dependency

Determine which dependency is missing or broken for a target-triplet build, verify whether it is present in the vcpkg installation tree, and provide actionable guidance to install or fix it. Produces a structured report that a coordinator agent can use to decide the next action.

## Goals

- PASS: Missing dependency identified, install status verified, fix command or overlay path provided.
- FAIL: Cannot determine missing dependency from available logs and installation tree.

## Capabilities

- Parse `find_package` and `pkg-config` failure messages from configure logs
- Cross-reference failures against the vcpkg installed tree (`installed/{triplet}/`)
- Check `vcpkg list` for installed packages matching the dependency name
- Inspect `vcpkg.json` manifest to verify dependency is declared
- Detect transitive dependency gaps and version conflicts
- Identify `REQUIRED` vs optional dependencies to prioritize fixes
- Detect Python 3, Java, Perl, Ruby, and other host-tool dependencies
- Emit machine-readable coordinator handoff

## User Input

- **Port name** (required): e.g. `opencv4`
- **Triplet** (optional): e.g. `x64-linux`; defaults to host triplet
- **Dependency name** (optional): skip log parsing and check a specific dependency directly
- **Buildtrees root** (optional): defaults to `buildtrees/`
- **Install root** (optional): defaults to `installed/`

## Process

Use targeted shell commands. Do NOT read entire log files or directory trees.

### Phase 1: Extract Missing Dependency Names from Logs

1. Parse find_package failures from configure logs:
   ```bash
   grep -n -E "Could NOT find ([A-Za-z0-9_\-]+)|find_package\(([A-Za-z0-9_\-]+).*REQUIRED\)" \
     buildtrees/{port-name}/config-{triplet}-out.log 2>/dev/null | head -30
   ```
2. Parse pkg-config failures:
   ```bash
   grep -n -E "No package '([^']+)' found|Package '([^']+)', required" \
     buildtrees/{port-name}/config-{triplet}-out.log \
     buildtrees/{port-name}/build-{triplet}-err.log 2>/dev/null | head -20
   ```
3. Parse linker undefined symbols (may indicate missing library):
   ```bash
   grep -n -E "undefined reference to `([^']+)'|undefined symbol: ([^ ]+)" \
     buildtrees/{port-name}/build-{triplet}-err.log 2>/dev/null | head -20
   ```
4. Extract missing header includes (may indicate missing dev package):
   ```bash
   grep -n -E "fatal error: ([^ ]+\.h(pp)?): No such file" \
     buildtrees/{port-name}/build-{triplet}-err.log 2>/dev/null | head -20
   ```

### Phase 2: Check vcpkg Manifest for Declared Dependencies

1. Read port manifest:
   ```bash
   cat ports/{port-name}/vcpkg.json
   ```
2. List declared dependencies and their features.
3. Check if the missing dependency is declared with correct feature flags.

### Phase 3: Verify vcpkg Installed Tree

1. Check installed tree for the dependency:
   ```bash
   ls installed/{triplet}/lib/ 2>/dev/null | grep -i {dependency-name} | head -10
   ls installed/{triplet}/include/ 2>/dev/null | grep -i {dependency-name} | head -10
   ```
2. Check vcpkg list:
   ```bash
   vcpkg list 2>/dev/null | grep -i {dependency-name} | head -10
   ```
3. Check for `.pc` files (pkg-config):
   ```bash
   ls installed/{triplet}/lib/pkgconfig/ 2>/dev/null | grep -i {dependency-name}
   ```
4. Check for CMake config files:
   ```bash
   find installed/{triplet}/share/ -name "{DependencyName}Config.cmake" \
     -o -name "{dependency-name}-config.cmake" 2>/dev/null | head -5
   ```

### Phase 4: Check Host Tool Dependencies

1. Python 3:
   ```bash
   python3 --version 2>/dev/null || echo "NOT FOUND"
   which python3 2>/dev/null
   ```
2. Java:
   ```bash
   java -version 2>/dev/null || echo "NOT FOUND"
   ```
3. Perl:
   ```bash
   perl --version 2>/dev/null | head -2 || echo "NOT FOUND"
   ```
4. Ruby:
   ```bash
   ruby --version 2>/dev/null || echo "NOT FOUND"
   ```
5. nasm / yasm (for crypto/media ports):
   ```bash
   nasm --version 2>/dev/null || echo "NOT FOUND"
   yasm --version 2>/dev/null || echo "NOT FOUND"
   ```

### Phase 5: Detect Version Conflicts

1. Check for version-mismatch indicators in logs:
   ```bash
   grep -n -iE "(version.*required|found version.*but.*required|incompatible version)" \
     buildtrees/{port-name}/config-{triplet}-out.log 2>/dev/null | head -10
   ```
2. Check baseline.json for pinned dependency version:
   ```bash
   grep -A 2 '"name": "{dependency-name}"' versions/baseline.json 2>/dev/null
   ```

### Phase 6: Classify Dependency Issue

| Class | Condition |
|-------|-----------|
| `NOT_INSTALLED` | Dependency not in `installed/{triplet}/`, not in `vcpkg list` |
| `NOT_DECLARED` | Dependency missing from `ports/{port-name}/vcpkg.json` |
| `VERSION_MISMATCH` | Installed version does not meet required version constraint |
| `FEATURE_MISSING` | Dependency installed but required feature not enabled |
| `HOST_TOOL_MISSING` | Python/Java/Perl/nasm not found on PATH |
| `PKG_CONFIG_MISSING` | `.pc` file not present in `lib/pkgconfig/` |
| `CMAKE_CONFIG_MISSING` | `*Config.cmake` file not found in `share/` |
| `UNKNOWN` | No clear category |

## Reporting

Output a markdown report with these headings (in order). Emit all headings even if empty (use `None`).

1. `# Dependency Failure Diagnostics`
2. `## Summary` — Port, triplet, timestamp, outcome (DEPENDENCY_IDENTIFIED / INCONCLUSIVE)
3. `## Missing Dependencies` — List of dependency names extracted from logs
4. `## Manifest Check` — Declared dependencies in `vcpkg.json`, gaps highlighted
5. `## Installed Tree Check` — What was found / not found in `installed/{triplet}/`
6. `## vcpkg List` — Matching installed packages
7. `## CMake Config Files` — Found / missing `*Config.cmake` in `share/`
8. `## pkg-config Files` — Found / missing `.pc` files
9. `## Host Tool Status` — Python3, Java, Perl, Ruby, nasm/yasm availability
10. `## Version Conflicts` — Version mismatch details if detected
11. `## Root Cause` — Classification label and primary missing item
12. `## Fix Command` — Exact vcpkg install command to resolve the dependency
13. `## Recommendations` — Ordered priority list
14. `## Coordinator Handoff` — Machine-readable one-line: `NEXT_SKILL: <skill-name> | REASON: <short reason>`

### Fix Command Template

```bash
vcpkg install --overlay-ports ./ports \
  --x-buildtrees-root buildtrees \
  --x-packages-root packages \
  --x-install-root installed \
  {missing-dependency}:{triplet}
```

### Coordinator Handoff Rules

| Root Cause Class | Suggested Next Skill |
|-----------------|---------------------|
| `NOT_INSTALLED` | `install-port` (install the dependency first) |
| `NOT_DECLARED` | `review-port` (add dependency to `vcpkg.json`) |
| `VERSION_MISMATCH` | `update-port` (update dependency version) |
| `FEATURE_MISSING` | `install-port` (reinstall with required feature) |
| `HOST_TOOL_MISSING` | `check-environment` |
| `PKG_CONFIG_MISSING` | `review-port` |
| `CMAKE_CONFIG_MISSING` | `review-port` |
| `UNKNOWN` | `diagnose-failed-configure` |

### Conventions
- Icons: ✅ found, ❌ missing, ⚠️ version issue
- Cite log path and line number for every extracted failure
- Quote only relevant lines (max 3 per dependency)
- List dependencies in order: REQUIRED first, then optional
- All paths relative to workspace root
