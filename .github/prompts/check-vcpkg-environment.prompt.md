---
description: 'Verify vcpkg installation, configuration, and registry structure'
agent: 'agent'
tools: ['search/fileSearch', 'search/listDirectory', 'search/readFile', 'runCommands/terminalLastCommand', 'runCommands/runInTerminal', 'fetch', 'edit/createFile']
model: Claude Haiku 4.5 (copilot)
---

# Check vcpkg Environment

Verify that vcpkg is properly installed, accessible, and correctly configured for this registry workspace.

## Prompt Goals

- Locate vcpkg installation (via `VCPKG_ROOT` or executable path)
- Verify vcpkg-tool version and warn if outdated
- Check registry folder structure (`ports/`, `versions/`, `triplets/`)
- List all vcpkg-related environment variables with values
- Explain `VCPKG_FEATURE_FLAGS` if set
- Generate structured environment report

## Workflow Expectation

**Default Behavior**: Runs autonomously to validate vcpkg setup. If `VCPKG_ROOT` is unset and `vcpkg` executable is not in PATH, searches common installation paths using GitHub Actions runner-images documentation as reference.

**Stop Conditions**:
- Successfully generates vcpkg environment report
- vcpkg cannot be located (error reported with resolution steps)

**Prompt Forwarding**: No automatic forwarding. Users typically proceed to `/search-port` or `/create-port`.

## User Input

No user input required. Automatically detects vcpkg configuration.

## Process

### Phase 1: Locate vcpkg Installation

#### Step 1.1: Check VCPKG_ROOT environment variable
- Tool: #tool:runCommands/runInTerminal
- Windows: `$env:VCPKG_ROOT; if ($env:VCPKG_ROOT) { Test-Path $env:VCPKG_ROOT }`
- Linux/macOS: `echo $VCPKG_ROOT; [ -d "$VCPKG_ROOT" ] && echo "exists"`
- Purpose: Primary method to find vcpkg root

#### Step 1.2: Check vcpkg in PATH
- Tool: #tool:runCommands/runInTerminal
- Windows: `Get-Command vcpkg -ErrorAction SilentlyContinue | Select-Object Source`
- Linux/macOS: `command -v vcpkg`
- Purpose: Fallback if VCPKG_ROOT not set

#### Step 1.3: Determine VCPKG_ROOT from executable location (if needed)
- Condition: VCPKG_ROOT not set but vcpkg found in PATH
- Action: Extract directory from executable path
- Tool: Parse terminal output

#### Step 1.4: Search common installation paths (fallback)
- Condition: Both previous methods failed
- Tool: #tool:fetch
- URL: `https://raw.githubusercontent.com/actions/runner-images/main/images/windows/Windows2022-Readme.md`
- Purpose: Get standard vcpkg installation locations
- Common paths:
  - Windows: `C:\vcpkg`, `C:\tools\vcpkg`, `C:\src\vcpkg`
  - Linux: `/usr/local/vcpkg`, `$HOME/vcpkg`, `/opt/vcpkg`
  - macOS: `/usr/local/vcpkg`, `$HOME/vcpkg`
- Tool: #tool:runCommands/runInTerminal - Test each path with `Test-Path` or `[ -d ]`

#### Step 1.5: Report findings or error
- Success: VCPKG_ROOT identified
- Failure: Report error with suggested resolution steps

### Phase 2: Validate vcpkg Installation

#### Step 2.1: Get vcpkg version
- Tool: #tool:runCommands/runInTerminal
- Command: `vcpkg --version` (or use absolute path if not in PATH)
- Purpose: Check vcpkg-tool version

#### Step 2.2: Parse and compare version
- Extract version from output (e.g., "2025-06-20")
- Compare with minimum recommended: `2025-06-20`
- Action: If older, issue warning with upgrade recommendation

#### Step 2.3: Verify critical directories
- Tool: #tool:search/fileSearch
- Patterns: `${VCPKG_ROOT}/scripts/**`, `${VCPKG_ROOT}/triplets/**`, `${VCPKG_ROOT}/ports/**`
- Purpose: Ensure vcpkg installation is complete

#### Step 2.4: Check vcpkg.cmake toolchain file
- Tool: #tool:search/readFile
- File: `${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake`
- Purpose: Verify toolchain file exists
- Note: Only verify existence, don't read full content

### Phase 3: Check Registry Configuration

#### Step 3.1: Search for vcpkg-configuration.json
- Tool: #tool:search/fileSearch
- Pattern: `**/vcpkg-configuration.json`
- Scope: Current workspace
- Purpose: Find registry configuration

#### Step 3.2: Read registry configuration (if exists)
- Tool: #tool:search/readFile
- File: Found vcpkg-configuration.json path
- Purpose: Check registered registries

#### Step 3.3: Verify registry folder structure
- Tool: #tool:search/listDirectory
- Paths: `ports/`, `versions/`, `triplets/`
- Purpose: Confirm registry layout

#### Step 3.4: Check baseline.json
- Tool: #tool:search/fileSearch
- Pattern: `versions/baseline.json`
- Purpose: Verify version tracking exists

### Phase 4: Check Environment Variables

#### Step 4.1: List all VCPKG_* variables
- Tool: #tool:runCommands/runInTerminal
- Windows: `Get-ChildItem Env: | Where-Object Name -like 'VCPKG*' | Format-Table Name, Value`
- Linux/macOS: `env | grep -i '^VCPKG' | sort`
- Purpose: Capture all vcpkg environment variables

#### Step 4.2: Capture variable output
- Tool: #tool:runCommands/terminalLastCommand
- Purpose: Store for reporting

#### Step 4.3: Explain VCPKG_FEATURE_FLAGS (if set)
- Condition: `VCPKG_FEATURE_FLAGS` detected
- Action: Parse flag value and explain each flag
- Common flags:
  - `versions`: Enable versioning support
  - `registries`: Enable registry support
  - `binarycaching`: Enable binary caching
  - `manifests`: Enable manifest mode
- Format: Brief 1-sentence descriptions

#### Step 4.4: Check overlay paths
- Variables: `VCPKG_OVERLAY_PORTS`, `VCPKG_OVERLAY_TRIPLETS`
- Action: If set, note values for reference

### Phase 5: Generate Report

#### Step 5.1: Compile findings
- Collect all detected information
- Format as structured markdown

## Reporting

Replace example reports with a deterministic specification. The agent MUST output a markdown report using the headings below (in order). Emit all headings; if no data for a section write `None`. Keep bullets concise (≤120 chars). No tables unless >6 environment variables.

### Required Top-Level Headings
1. `# vcpkg Environment Check Report`
2. `## Summary`
3. `## Installation`
4. `## Version Status`
5. `## Registry Structure`
6. `## Configuration File`
7. `## Environment Variables`
8. `## Feature Flags`
9. `## Diagnostics`
10. `## Recommendations`
11. `## Next Steps`

### 1. Summary
- Timestamp: ISO 8601 UTC (`YYYY-MM-DD HH:MM:SS UTC`)
- Outcome: `OK` | `WARN` | `ERROR`
- VCPKG_ROOT: path or `unset`
- Executable Path: absolute path or `not found`

### 2. Installation
- Root Exists: ✅/❌
- Executable Found: ✅/❌ (with path)
- Toolchain File: exists ✅/❌ (`scripts/buildsystems/vcpkg.cmake`)
- Critical Directories: `scripts` / `ports` / `triplets` presence ✅/❌

### 3. Version Status
- Detected Version: raw string from `vcpkg --version`
- Parsed Date Tag: `<YYYY-MM-DD>` or `unknown`
- Minimum Recommended: `2025-06-20` (adjust if policy changes)
- Status: `current` | `outdated` | `unknown`
- Upgrade URL: `https://github.com/microsoft/vcpkg-tool/releases` (if outdated)

### 4. Registry Structure
- Registry Root: workspace path
- Ports Folder: exists ✅/❌ + count of immediate subdirs
- Versions Folder: exists ✅/❌ + baseline.json ✅/❌
- Triplets Folder: exists ✅/❌ + count of triplet files

### 5. Configuration File
- vcpkg-configuration.json: path or `None`
- Registries Declared: count or `None`
- Default Registry: short summary (baseline SHA prefix) or `None`

### 6. Environment Variables
List each `VCPKG_*` variable present:
- `VCPKG_ROOT=...`
- `VCPKG_FEATURE_FLAGS=...`
- `VCPKG_OVERLAY_PORTS=...`
- `VCPKG_OVERLAY_TRIPLETS=...`
- `VCPKG_BINARY_SOURCES=...`
If >6 total variables, table allowed; else bullets. Missing variables omitted.

### 7. Feature Flags
- Raw Value: comma list or `None`
- Parsed Flags: bullet each with 1-line meaning (versions, registries, binarycaching, manifests, compilertracking, metrics)
- Unknown Flags: list or `None`

### 8. Diagnostics
- PATH Contains vcpkg: yes/no
- Inferred Root From Executable: path or `None`
- Searched Fallback Paths: list checked (only if not found) or `None`
- Missing Components: list of absent critical items or `None`

### 9. Recommendations
Bulleted actions prioritized:
- Set VCPKG_ROOT
- Upgrade vcpkg-tool
- Add feature flags (if empty) for versioning/registries
- Add baseline.json (if missing)
- Verify overlay paths
If nothing to recommend: `None`

### 10. Next Steps
Ordered immediate suggestions:
1. For ERROR: install or set VCPKG_ROOT
2. For WARN (outdated): upgrade tool
3. For OK: proceed to `/search-port` or `/create-port`

### Conventions
- Icons: ✅ present, ❌ missing, ⚠️ warning (outdated / partial)
- Avoid full file dumps; only list counts & paths
- Use relative workspace paths when referencing registry folders
- Do not duplicate installation details already shown; keep each item single line

### Failure Mode (vcpkg not found)
Still emit all headings. Populate Installation/Diagnostics with missing items and list resolution steps under Recommendations.

### Non-Blocking Warnings
- Outdated version but functional
- Missing optional overlay variables

### Blocking Errors
- Executable missing
- Toolchain file absent
- Root folder inaccessible

This specification replaces previous example reports; emit only real environment data.
