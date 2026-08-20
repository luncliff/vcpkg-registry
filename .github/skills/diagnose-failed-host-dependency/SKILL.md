---
name: diagnose-failed-host-dependency
description: Identify and diagnose a missing or misconfigured host-triplet dependency (tools, generators, or host libraries) that is blocking a vcpkg cross-compilation port build. Use when a cross-compile port fails due to a missing host tool or host-context library.
---

# Diagnose Failed Host Dependency

Determine which host-triplet dependency (build tool, code generator, or host-architecture library) is missing or broken for a cross-compilation build. Verifies the host installed tree, native tool paths, and host-context vcpkg packages. Produces a structured report with coordinator handoff.

## Goals

- PASS: Missing host dependency identified, install status verified, fix command or path provided.
- FAIL: Cannot determine missing host dependency from available logs and installation tree.

## Capabilities

- Distinguish host-triplet failures from target-triplet dependency failures
- Parse error messages that reference host tools: protoc, flatc, grpc_cpp_plugin, spirv-cross, etc.
- Verify host vcpkg installed tree (`installed/{host-triplet}/`)
- Check `vcpkg.json` for `"host": true` dependency declarations
- Detect missing code generators, schema compilers, and binary tools required at build time
- Inspect `PATH` for host tool availability
- Report correct host triplet inference from environment
- Detect Python 3 and other host scripting runtimes needed by code generators
- Emit machine-readable coordinator handoff

## User Input

- **Port name** (required): e.g. `grpc`
- **Target triplet** (optional): e.g. `arm64-android`; defaults to host triplet
- **Host triplet** (optional): e.g. `x64-linux`; inferred from environment if omitted
- **Buildtrees root** (optional): defaults to `buildtrees/`
- **Install root** (optional): defaults to `installed/`

## Process

Use targeted shell commands. Do NOT read entire log files or directory trees.

### Phase 1: Determine Host Triplet

1. Infer host triplet from vcpkg:
   ```bash
   vcpkg version 2>/dev/null | grep -i "triplet\|host" | head -5
   ```
2. Check environment variable:
   ```bash
   echo "VCPKG_DEFAULT_HOST_TRIPLET=${VCPKG_DEFAULT_HOST_TRIPLET:-not set}"
   ```
3. Infer from OS/arch:
   - Linux x86_64 → `x64-linux`
   - macOS arm64 → `arm64-osx`
   - macOS x86_64 → `x64-osx`
   - Windows x64 → `x64-windows`

### Phase 2: Extract Host Tool Errors from Logs

1. Grep configure log for executable/tool not found:
   ```bash
   grep -n -E "(NOTFOUND|not found|Could not find|No such file).*\b(protoc|flatc|grpc_cpp_plugin|spirv-cross|glslangValidator|glslc|dxc|shader|gen|tool)\b" \
     buildtrees/{port-name}/config-{triplet}-out.log 2>/dev/null | head -20
   ```
2. Grep for `find_program` failures:
   ```bash
   grep -n -E "find_program.*NOTFOUND|Could NOT find program" \
     buildtrees/{port-name}/config-{triplet}-out.log 2>/dev/null | head -20
   ```
3. Grep build log for host binary execution errors:
   ```bash
   grep -n -E "(Exec format error|cannot execute binary file|Bad CPU type in executable|No such file or directory:.*bin/)" \
     buildtrees/{port-name}/build-{triplet}-err.log 2>/dev/null | head -20
   ```
4. Grep for cross-compile tool invocation errors:
   ```bash
   grep -n -E "(protoc|flatc|grpc_cpp_plugin|spirv-cross|glslangValidator|glslc|dxc): .*(not found|error|failed|No such)" \
     buildtrees/{port-name}/build-{triplet}-err.log 2>/dev/null | head -20
   ```

### Phase 3: Check Host Dependency Declarations in Manifest

1. Read port manifest:
   ```bash
   cat ports/{port-name}/vcpkg.json
   ```
2. Extract dependencies with `"host": true`:
   ```bash
   grep -A 3 '"host": *true' ports/{port-name}/vcpkg.json | head -30
   ```
3. List all declared host dependencies.

### Phase 4: Verify Host Installed Tree

1. Check for host tools in the host installed tree:
   ```bash
   ls installed/{host-triplet}/tools/ 2>/dev/null | head -20
   ```
2. Check for host tool binary files:
   ```bash
   find installed/{host-triplet}/tools/ -type f -name "protoc" \
     -o -name "flatc" -o -name "grpc_cpp_plugin" \
     -o -name "spirv-cross" -o -name "glslangValidator" \
     -o -name "glslc" -o -name "dxc" 2>/dev/null | head -10
   ```
3. Check vcpkg list for host packages (substitute the actual host triplet determined in Phase 1):
   ```bash
   vcpkg list 2>/dev/null | grep ":{host-triplet}" | head -20
   # Example: vcpkg list 2>/dev/null | grep ":x64-linux" | head -20
   ```

### Phase 5: Check System PATH for Host Tools

1. Common code generators:
   ```bash
   for tool in protoc flatc grpc_cpp_plugin spirv-cross glslangValidator glslc dxc moc rcc uic; do
     which "$tool" 2>/dev/null && echo "FOUND: $tool" || echo "MISSING: $tool"
   done
   ```
2. Script interpreters:
   ```bash
   for tool in python3 python perl ruby node npm; do
     which "$tool" 2>/dev/null && "$tool" --version 2>&1 | head -1 || echo "MISSING: $tool"
   done
   ```
3. Build-time tools:
   ```bash
   for tool in cmake ninja make nasm yasm bison flex gperf; do
     which "$tool" 2>/dev/null && echo "FOUND: $tool" || echo "MISSING: $tool"
   done
   ```

### Phase 6: Detect Host vs Target Confusion

1. Check if a target-triplet binary is being invoked on the host:
   ```bash
   grep -n -E "Exec format error|Bad CPU type in executable|cannot execute binary file" \
     buildtrees/{port-name}/build-{triplet}-err.log 2>/dev/null | head -10
   ```
2. Verify that host tool dependencies are declared with `"host": true` in `vcpkg.json`.
3. Check if a host dependency port exists in this registry or in vcpkg baseline:
   ```bash
   ls ports/ | grep -i {tool-name} | head -5
   grep '"name"' versions/baseline.json | grep -i {tool-name} | head -5
   ```

### Phase 7: Classify Host Dependency Issue

| Class | Condition |
|-------|-----------|
| `HOST_TOOL_NOT_INSTALLED` | Tool not in `installed/{host-triplet}/tools/` and not on PATH |
| `NOT_DECLARED_AS_HOST` | Dependency present in manifest but without `"host": true` |
| `HOST_TRIPLET_MISMATCH` | Tool binary built for wrong architecture (Exec format error) |
| `HOST_PORT_MISSING` | vcpkg port for the tool does not exist in registry or vcpkg |
| `SCRIPT_RUNTIME_MISSING` | Python3/Perl/Ruby/Node required by code generator not found |
| `HOST_TOOL_PATH_MISSING` | Tool exists but not on PATH or not referenced correctly |
| `UNKNOWN` | No clear category |

## Reporting

Output a markdown report with these headings (in order). Emit all headings even if empty (use `None`).

1. `# Host Dependency Failure Diagnostics`
2. `## Summary` — Port, target triplet, host triplet (inferred/set), timestamp, outcome (HOST_DEP_IDENTIFIED / INCONCLUSIVE)
3. `## Host Triplet` — Inferred or configured value, source (env var / vcpkg / OS inference)
4. `## Host Tool Errors` — Tool names extracted from logs, with log path:line
5. `## Manifest Host Dependencies` — Declared `"host": true` entries, gaps highlighted
6. `## Host Installed Tree` — What was found / not found in `installed/{host-triplet}/tools/`
7. `## System PATH Tools` — Status of each checked tool (FOUND / MISSING with path)
8. `## Script Runtimes` — Python3, Perl, Ruby, Node availability and version
9. `## Host vs Target Confusion` — Exec format errors, architecture mismatch findings
10. `## Root Cause` — Classification label and primary missing item
11. `## Fix Command` — Exact vcpkg install command to resolve the host dependency
12. `## Recommendations` — Ordered priority list
13. `## Coordinator Handoff` — Machine-readable one-line: `NEXT_SKILL: <skill-name> | REASON: <short reason>`

### Fix Command Template

For a missing host tool via vcpkg:
```bash
vcpkg install --overlay-ports ./ports \
  --x-buildtrees-root buildtrees \
  --x-packages-root packages \
  --x-install-root installed \
  {tool-port-name}:{host-triplet}
```

For a system tool (non-vcpkg), provide the OS-appropriate install command:
- Ubuntu/Debian: `sudo apt-get install {package}`
- macOS: `brew install {package}`
- Windows: `winget install {package}` or `choco install {package}`

### Coordinator Handoff Rules

| Root Cause Class | Suggested Next Skill |
|-----------------|---------------------|
| `HOST_TOOL_NOT_INSTALLED` | `install-port` (install host tool port) |
| `NOT_DECLARED_AS_HOST` | `review-port` (add `"host": true` to vcpkg.json) |
| `HOST_TRIPLET_MISMATCH` | `check-environment` |
| `HOST_PORT_MISSING` | `search-port` (find or create the tool port) |
| `SCRIPT_RUNTIME_MISSING` | `check-environment` |
| `HOST_TOOL_PATH_MISSING` | `check-environment` |
| `UNKNOWN` | `diagnose-failed-configure` |

### Conventions
- Icons: ✅ found, ❌ missing, ⚠️ mismatch/warning
- Always report both host and target triplet
- Cite log path and line number for every extracted error
- Quote only relevant lines (max 3 per finding)
- All paths relative to workspace root
