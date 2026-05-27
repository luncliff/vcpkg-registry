---
name: install-port
description: Install a vcpkg port with overlay-ports and analyze build logs. Use when asked to install, test, or build a port.
---

# Install Port

Execute vcpkg port installation with overlay-ports, monitor build process, and analyze results (success or failure).

## Goals

- PASS: Port installed successfully with overlays; key checks validated; artifacts confirmed.
- FAIL: Install failed with clear error classification (CMake/compiler/linker/vcpkg configuration) and suggested next steps.

## Capabilities

- Parse port installation request with features and triplet
- Execute `vcpkg install` with correct overlay-ports configuration
- Monitor terminal output for errors
- Analyze build logs if installation fails
- Report installation results with actionable recommendations

## User Input

**Supported Patterns**:
- Port names: `openssl3`, `tensorflow-lite`
- With features: `opencv4[opengl,ffmpeg]`
- With triplet: `zlib-ng:x64-windows`, `cpuinfo:arm64-android`
- Multiple ports: `openssl3 zlib-ng cpuinfo`
- With editable: `install openssl3 --editable` (for development)

## Process

### Phase 1: Parse Installation Request

1. Extract: port names, features, triplet, editable flag
2. Verify port exists in `ports/{port-name}/`
3. Validate triplet: check `triplets/{triplet}.cmake` exists (fallback: default host triplet)
4. Verify requested features exist in port manifest

### Phase 2: Pre-Installation Checks

1. Verify `VCPKG_ROOT` environment variable
2. Check vcpkg version: `vcpkg version`
3. Optionally clean previous install (if fresh install requested)

### Phase 3: Execute Installation

1. Construct install command:
   ```powershell
   vcpkg install --overlay-ports ./ports `
     --x-buildtrees-root buildtrees `
     --x-packages-root packages `
     --x-install-root installed `
     {port-name}
   ```
   Or for Bash/Zsh:
   ```bash
   vcpkg install --overlay-ports ./ports \
     --x-buildtrees-root buildtrees \
     --x-packages-root packages \
     --x-install-root installed \
     {port-name}
   ```
2. Add `--overlay-triplets ./triplets --triplet {triplet}` if custom triplet
3. Add `--editable` if development mode
4. Wait for completion

### Phase 4: Analyze Results

1. Check exit code (0 = success)
2. If success: extract installation time, dependencies built
3. If failure: read build logs in order:
   - `buildtrees/{port-name}/config-{triplet}-out.log`
   - `buildtrees/{port-name}/install-{triplet}-out.log`
   - `buildtrees/{port-name}/build-{triplet}-out.log`
4. Identify error patterns:
   - CMake: `CMake Error`, `Could NOT find`
   - Compiler: `error C2XXX`, `error: ...`
   - Linker: `unresolved external symbol`, `undefined reference`
   - Dependency: `Package ... is not installed`

### Phase 5: Post-Installation Verification (if success)

1. Check installed files in `packages/{port-name}_*/` or `installed/{triplet}/`
2. List installed headers
3. List installed libraries
4. Check usage file

## Reporting

Output a markdown report with these headings (in order). Emit all headings even if empty (use `None`).

1. `# Port Installation Report`
2. `## Summary` — Port specification, timestamp, mode, outcome (SUCCESS/FAILURE), duration
3. `## Command` — Exact invocation in fenced block
4. `## Result` — Status icon, dependencies built, features enabled
5. `## Artifacts` — Headers, libraries, binaries (success only)
6. `## Usage` — Usage file content or generic find_package snippet
7. `## Errors` — Primary error type, first error line, count (failure only)
8. `## Diagnostics` — Log files checked, highlighted patterns, missing dependencies
9. `## Recommendations` — Actionable fixes (failure) or follow-up (success)
10. `## Next Steps` — Ordered priority list

### Error Classification Rules
- CMake: contains `CMake Error` or `Could NOT find`
- Compiler: `error C` (MSVC) or `error:` (gcc/clang)
- Linker: `unresolved external symbol` / `undefined reference`
- Dependency: manifest missing required library
- Platform: environment/SDK variables missing
- Unknown: none of the above matched

### Conventions
- Icons: ✅ success, ❌ failure, ⚠️ warning
- Trim lists >5 items with `... (+N more)`
- Do not dump entire build logs; reference path only
- All paths relative to workspace root

## References

- [docs/guide-create-port-build.md](../../docs/guide-create-port-build.md)
- [docs/troubleshooting.md](../../docs/troubleshooting.md)
