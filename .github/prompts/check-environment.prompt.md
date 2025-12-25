---
description: 'Detect OS/shell, validate vcpkg setup, and emit one combined environment report'
agent: 'agent'
tools: ['execute/runInTerminal', 'read/readFile', 'read/terminalLastCommand', 'search/fileSearch', 'search/listDirectory', 'web/fetch', 'todo']
model: Claude Haiku 4.5 (copilot)
---

# vcpkg-registry: Check Environment (Merged)

Run a unified check that first detects the host OS and shell, verifies key developer tools, then validates vcpkg installation and registry structure. Produces a single consolidated markdown report.

## Prompt Goals

- PASS: Environment is suitable for building ports with vcpkg-registry; all critical tools and paths validated.
- FAIL: Missing critical tools or misconfigured environment; actionable fixes provided.

**Additional Goals**:
- Identify operating system and shell (Windows/PowerShell prioritized)
- Verify minimum tool availability (curl, tar, zip, unzip, git, cmake, ninja)
- Locate and validate vcpkg (`VCPKG_ROOT` or PATH)
- Check vcpkg-tool version and critical directories
- Verify registry folders in current workspace (`ports/`, `versions/`, `triplets/`)
- Enumerate `VCPKG_*` environment variables and explain `VCPKG_FEATURE_FLAGS`
- Emit one structured report for reproducibility

## Workflow Expectation

- Default Behavior: Runs autonomously end-to-end and emits a single combined report.
- Stop Conditions: Report generated, even if warnings/errors are present.
- Eagerness: Prevent asking user for question or additional input.

## User Input

No input required. Automatically detects environment and vcpkg configuration.

## Process

- Do use short shell commands. Do NOT use complicated scripts.

### Phase 1: Detect Operating System & Shell

#### Step 1.1: OS detection
- Tool: #tool:execute/runInTerminal
- Windows: `$PSVersionTable.PSVersion`
- Linux/macOS: `uname -s`
- Purpose: Determine OS family

#### Step 1.2: System details
- Tool: #tool:execute/runInTerminal
- Windows: `Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsArchitecture`
- Linux: `uname -a; lsb_release -a 2>/dev/null || cat /etc/os-release`
- macOS: `sw_vers; uname -m`
- Purpose: Capture version/architecture

#### Step 1.3: Shell info
- Tool: #tool:execute/runInTerminal
- Windows: `$PSVersionTable.PSEdition; $PSVersionTable.PSVersion`
- Linux/macOS: `echo $SHELL; $SHELL --version`
- Purpose: Determine shell type/version

#### Step 1.4: Tool availability (Windows template used on Windows)
- Tool: #tool:execute/runInTerminal
- Windows (PowerShell): iterate `curl`, `tar`, `zip`, `unzip`, `git`, `cmake`, `ninja`
  - Template: `Get-Command <exe> -ErrorAction SilentlyContinue | Select-Object Source`
- POSIX shells: `command -v <exe>; <exe> --version 2>/dev/null`

#### Step 1.5: Cross-platform translation references (non-Windows only)
- Tool: #tool:web/fetch
- URLs: 
  - https://github.com/actions/runner-images/blob/main/README.md
  - https://docs.github.com/en/actions/concepts/runners/github-hosted-runners
- Purpose: Inform translation of PowerShell → Bash/Zsh examples

### Phase 2: Locate and Validate vcpkg

#### Step 2.1: Check `VCPKG_ROOT`
- Tool: #tool:execute/runInTerminal
- Windows: `$env:VCPKG_ROOT; if ($env:VCPKG_ROOT) { Test-Path $env:VCPKG_ROOT }`
- Linux/macOS: `echo $VCPKG_ROOT; [ -d "$VCPKG_ROOT" ] && echo "exists"`

#### Step 2.2: Check `vcpkg` in PATH
- Tool: #tool:execute/runInTerminal
- Windows: `Get-Command vcpkg -ErrorAction SilentlyContinue | Select-Object Source`
- Linux/macOS: `command -v vcpkg`

#### Step 2.3: Infer `VCPKG_ROOT` from executable (if unset but found)
- Action: Parse executable path parent directory

#### Step 2.4: Fallback search (if still unknown)
- Tool: #tool:web/fetch
- URL: https://raw.githubusercontent.com/actions/runner-images/main/images/windows/Windows2022-Readme.md
- Common paths to test:
  - Windows: `C:\vcpkg`, `C:\tools\vcpkg`, `C:\src\vcpkg`
  - Linux: `/usr/local/vcpkg`, `$HOME/vcpkg`, `/opt/vcpkg`
  - macOS: `/usr/local/vcpkg`, `$HOME/vcpkg`
- Tool: #tool:execute/runInTerminal — `Test-Path` / `[ -d ]`

#### Step 2.5: Get vcpkg version
- Tool: #tool:execute/runInTerminal
- Command: `vcpkg --version` (use absolute path if needed)
- Minimum recommended: `2025-06-20`

#### Step 2.6: Verify critical directories
- Tool: #tool:search/fileSearch
- Patterns: `${VCPKG_ROOT}/scripts/**`, `${VCPKG_ROOT}/triplets/**`, `${VCPKG_ROOT}/ports/**`

#### Step 2.7: Check toolchain file
- Tool: #tool:read/readFile
- File: `${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake`
- Purpose: Existence check only

### Phase 3: Check Registry Structure (Current Workspace)

#### Step 3.1: Locate `vcpkg-configuration.json`
- Tool: #tool:search/fileSearch
- Pattern: `**/vcpkg-configuration.json`

#### Step 3.2: Read config (if found)
- Tool: #tool:read/readFile

#### Step 3.3: Verify folders
- Tool: #tool:search/listDirectory
- Paths: `ports/`, `versions/`, `triplets/`

#### Step 3.4: Check `baseline.json`
- Tool: #tool:search/fileSearch
- Pattern: `versions/baseline.json`

#### Step 3.5: List vcpkg-related environment variables
- Tool: #tool:execute/runInTerminal
- Windows: `Get-ChildItem Env: | Where-Object Name -like 'VCPKG*' | Format-Table Name, Value`
- Linux/macOS: `env | grep -i '^VCPKG' | sort`

### Phase 4: Generate Combined Report

The agent MUST output a single markdown report containing the exact headings (in order) below. If a section has no data, write `None`. Use emojis for status lines (✅ ⚠️ ❌). Keep bullets concise (≤120 chars). Use tables only when listing >6 environment variables or >5 tool translations.

#### Required Top-Level Headings
1. `# Combined Environment Report`
2. `## Summary`
3. `## System`
4. `## Shell`
5. `## Tools`
6. `## vcpkg Installation`
7. `## Version Status`
8. `## Registry Structure`
9. `## Configuration File`
10. `## Environment Variables`
11. `## Feature Flags`
12. `## Diagnostics`
13. `## Recommendations`
14. `## Next Steps`

### 1. Summary
- Timestamp: ISO 8601 UTC (`YYYY-MM-DD HH:MM:SS UTC`)
- OS Family: `Windows` | `Linux` | `macOS`
- Architecture: `x64` | `arm64` | etc.
- Shell: name + version
- Outcome: `READY` | `WARN` | `ERROR`

### 2. System
- OS Detailed: version/build
- Hostname: or `None`
- Kernel (Unix): `uname -r` or `None`
- Distribution (Linux): `/etc/os-release` or `None`

### 3. Shell
- Shell Name: `PowerShell` | `bash` | `zsh` | other
- Version: parsed value
- Edition (PowerShell): `Desktop` | `Core` | `None`
- Minimum Requirement (PowerShell ≥7.1): met ✅ / unmet ❌ / not applicable

### 4. Tools
- Report each of: `curl`, `tar`, `zip`, `unzip`, `git`, `cmake`, `ninja`
- Value: `version` (raw first token) or `missing`
- Optional: `python` version or `missing`

### 5. vcpkg Installation
- VCPKG_ROOT: path or `unset`
- Root Exists: ✅/❌
- Executable Found: ✅/❌ (with path)
- Toolchain File: exists ✅/❌ (`scripts/buildsystems/vcpkg.cmake`)
- Critical Dirs: `scripts` / `ports` / `triplets` presence ✅/❌

### 6. Version Status
- Detected Version: raw `vcpkg --version`
- Parsed Date Tag: `<YYYY-MM-DD>` or `unknown`
- Minimum Recommended: `2025-06-20`
- Status: `current` | `outdated` | `unknown`
- Upgrade URL: `https://github.com/microsoft/vcpkg-tool/releases` (if outdated)

### 7. Registry Structure
- Registry Root: workspace path
- Ports Folder: exists ✅/❌ + count of immediate subdirs
- Versions Folder: exists ✅/❌ + baseline.json ✅/❌
- Triplets Folder: exists ✅/❌ + count of triplet files

### 8. Configuration File
- vcpkg-configuration.json: path or `None`
- Registries Declared: count or `None`
- Default Registry: short summary (baseline SHA prefix) or `None`

### 9. Environment Variables
- List each `VCPKG_*` variable present
- If >6 total, use a table

### 10. Feature Flags
- Raw Value: comma list or `None`
- Parsed Flags: brief meaning for: versions, registries, binarycaching, manifests, compilertracking, metrics
- Unknown Flags: list or `None`

### 11. Diagnostics
- PATH Contains vcpkg: yes/no
- Inferred Root From Executable: path or `None`
- Searched Fallback Paths: list checked (only if not found) or `None`
- Missing Components: absent critical items or `None`
- Cross-Platform Translations: emit mappings only if shell ≠ PowerShell OR non-Windows; else `None`
  - `$env:VAR` → `$VAR`
  - `Get-ChildItem Env:` → `env | sort`
  - `Test-Path <path>` → `[ -e <path> ]`
  - `Get-Command name` → `command -v name`
  - `Remove-Item path` → `rm -rf path`

### 12. Recommendations
- Prioritized actions: install missing tools, set `VCPKG_ROOT`, upgrade vcpkg-tool, validate overlays
- `None` if nothing to recommend

### 13. Next Steps
- For READY: suggest `/search-port` or `/create-port`
- For WARN: perform upgrades then re-run check
- For ERROR: install/fix missing items first

## Conventions
- Use ✅ ⚠️ ❌ where applicable
- Keep results concise; no full dumps
- Prefer PowerShell commands on Windows; provide POSIX translations only when needed
