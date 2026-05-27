---
name: check-environment
description: Detect OS/shell, validate vcpkg setup, and emit a combined environment report. Use when asked to check the environment, verify setup, or troubleshoot vcpkg configuration.
---

# Check Environment

Run a unified check that detects the host OS and shell, verifies key developer tools, validates vcpkg installation and registry structure. Produces a single consolidated markdown report.

## Goals

- PASS: Environment is suitable for building ports with vcpkg-registry; all critical tools and paths validated.
- FAIL: Missing critical tools or misconfigured environment; actionable fixes provided.

## Capabilities

- Identify operating system and shell (Windows/PowerShell prioritized)
- Verify minimum tool availability (curl, tar, zip, unzip, git, cmake, ninja)
- Locate and validate vcpkg (`VCPKG_ROOT` or PATH)
- Check vcpkg-tool version and critical directories
- Verify registry folders in current workspace (`ports/`, `versions/`, `triplets/`)
- Enumerate `VCPKG_*` environment variables and explain `VCPKG_FEATURE_FLAGS`
- Emit one structured report for reproducibility

## User Input

No input required. Automatically detects environment and vcpkg configuration.

## Process

Use short shell commands. Do NOT use complicated scripts.

### Phase 1: Detect Operating System & Shell

1. OS detection:
   - Windows: `$PSVersionTable.PSVersion`
   - Linux/macOS: `uname -s`
2. System details:
   - Windows: `Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsArchitecture`
   - Linux: `uname -a; lsb_release -a 2>/dev/null || cat /etc/os-release`
   - macOS: `sw_vers; uname -m`
3. Shell info:
   - Windows: `$PSVersionTable.PSEdition; $PSVersionTable.PSVersion`
   - Linux/macOS: `echo $SHELL; $SHELL --version`
4. Tool availability: check `curl`, `tar`, `zip`, `unzip`, `git`, `cmake`, `ninja`

### Phase 2: Locate and Validate vcpkg

1. Check `VCPKG_ROOT` environment variable
2. Check `vcpkg` in PATH
3. Infer `VCPKG_ROOT` from executable path if unset
4. Fallback search: common paths (`C:\vcpkg`, `/usr/local/vcpkg`, `$HOME/vcpkg`)
5. Get vcpkg version: `vcpkg --version` (minimum recommended: `2025-06-20`)
6. Verify critical directories: `scripts/`, `triplets/`, `ports/`
7. Check toolchain file: `${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake`

### Phase 3: Check Registry Structure

1. Locate `vcpkg-configuration.json`
2. Verify folders: `ports/`, `versions/`, `triplets/`
3. Check `versions/baseline.json`
4. List vcpkg-related environment variables:
   - Windows: `Get-ChildItem Env: | Where-Object Name -like 'VCPKG*'`
   - Linux/macOS: `env | grep -i '^VCPKG' | sort`

## Reporting

Output a single markdown report with these headings (in order). Emit all headings even if empty (use `None`).

1. `# Combined Environment Report`
2. `## Summary` — Timestamp, OS family, architecture, shell, outcome (READY/WARN/ERROR)
3. `## System` — OS detailed, hostname, kernel, distribution
4. `## Shell` — Shell name, version, edition
5. `## Tools` — Each of curl/tar/zip/unzip/git/cmake/ninja with version or `missing`
6. `## vcpkg Installation` — VCPKG_ROOT, root exists, executable found, toolchain file, critical dirs
7. `## Version Status` — Detected version, parsed date tag, minimum recommended, status
8. `## Registry Structure` — Registry root, ports/versions/triplets folder presence and counts
9. `## Configuration File` — vcpkg-configuration.json path, registries, default registry
10. `## Environment Variables` — List each `VCPKG_*` variable
11. `## Feature Flags` — Raw value, parsed flags, unknown flags
12. `## Diagnostics` — PATH contains vcpkg, inferred root, missing components, cross-platform translations
13. `## Recommendations` — Install missing tools, set VCPKG_ROOT, upgrade vcpkg-tool
14. `## Next Steps` — Based on READY/WARN/ERROR status

### Conventions
- Use ✅ ⚠️ ❌ where applicable
- Keep results concise; no full dumps
- Prefer PowerShell commands on Windows; provide POSIX translations only when needed

## Next Steps Guidance

- READY: suggest `search-port` or `create-port` skill
- WARN: perform upgrades then re-run check
- ERROR: install/fix missing items first

## References

- [docs/troubleshooting.md](../../docs/troubleshooting.md)
- [docs/references.md](../../docs/references.md)
