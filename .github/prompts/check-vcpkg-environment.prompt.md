---
description: 'Verify vcpkg installation, configuration, and registry structure'
agent: 'agent'
tools: ['search/fileSearch', 'search/listDirectory', 'search/readFile', 'runCommands/terminalLastCommand', 'runCommands/runInTerminal', 'fetch']
model: GPT-5 mini (copilot)
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
- Tool: `#runInTerminal`
- Windows: `$env:VCPKG_ROOT; if ($env:VCPKG_ROOT) { Test-Path $env:VCPKG_ROOT }`
- Linux/macOS: `echo $VCPKG_ROOT; [ -d "$VCPKG_ROOT" ] && echo "exists"`
- Purpose: Primary method to find vcpkg root

#### Step 1.2: Check vcpkg in PATH
- Tool: `#runInTerminal`
- Windows: `Get-Command vcpkg -ErrorAction SilentlyContinue | Select-Object Source`
- Linux/macOS: `command -v vcpkg`
- Purpose: Fallback if VCPKG_ROOT not set

#### Step 1.3: Determine VCPKG_ROOT from executable location (if needed)
- Condition: VCPKG_ROOT not set but vcpkg found in PATH
- Action: Extract directory from executable path
- Tool: Parse terminal output

#### Step 1.4: Search common installation paths (fallback)
- Condition: Both previous methods failed
- Tool: `#fetch`
- URL: `https://raw.githubusercontent.com/actions/runner-images/main/images/windows/Windows2022-Readme.md`
- Purpose: Get standard vcpkg installation locations
- Common paths:
  - Windows: `C:\vcpkg`, `C:\tools\vcpkg`, `C:\src\vcpkg`
  - Linux: `/usr/local/vcpkg`, `$HOME/vcpkg`, `/opt/vcpkg`
  - macOS: `/usr/local/vcpkg`, `$HOME/vcpkg`
- Tool: `#runInTerminal` - Test each path with `Test-Path` or `[ -d ]`

#### Step 1.5: Report findings or error
- Success: VCPKG_ROOT identified
- Failure: Report error with suggested resolution steps

### Phase 2: Validate vcpkg Installation

#### Step 2.1: Get vcpkg version
- Tool: `#runInTerminal`
- Command: `vcpkg --version` (or use absolute path if not in PATH)
- Purpose: Check vcpkg-tool version

#### Step 2.2: Parse and compare version
- Extract version from output (e.g., "2025-06-20")
- Compare with minimum recommended: `2025-06-20`
- Action: If older, issue warning with upgrade recommendation

#### Step 2.3: Verify critical directories
- Tool: `#fileSearch`
- Patterns: `${VCPKG_ROOT}/scripts/**`, `${VCPKG_ROOT}/triplets/**`, `${VCPKG_ROOT}/ports/**`
- Purpose: Ensure vcpkg installation is complete

#### Step 2.4: Check vcpkg.cmake toolchain file
- Tool: `#readFile`
- File: `${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake`
- Purpose: Verify toolchain file exists
- Note: Only verify existence, don't read full content

### Phase 3: Check Registry Configuration

#### Step 3.1: Search for vcpkg-configuration.json
- Tool: `#fileSearch`
- Pattern: `**/vcpkg-configuration.json`
- Scope: Current workspace
- Purpose: Find registry configuration

#### Step 3.2: Read registry configuration (if exists)
- Tool: `#readFile`
- File: Found vcpkg-configuration.json path
- Purpose: Check registered registries

#### Step 3.3: Verify registry folder structure
- Tool: `#listDirectory`
- Paths: `ports/`, `versions/`, `triplets/`
- Purpose: Confirm registry layout

#### Step 3.4: Check baseline.json
- Tool: `#fileSearch`
- Pattern: `versions/baseline.json`
- Purpose: Verify version tracking exists

### Phase 4: Check Environment Variables

#### Step 4.1: List all VCPKG_* variables
- Tool: `#runInTerminal`
- Windows: `Get-ChildItem Env: | Where-Object Name -like 'VCPKG*' | Format-Table Name, Value`
- Linux/macOS: `env | grep -i '^VCPKG' | sort`
- Purpose: Capture all vcpkg environment variables

#### Step 4.2: Capture variable output
- Tool: `#terminalLastCommand`
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

#### Step 5.2: Update work-note.md
- Tool: `#editFiles` (append mode)
- Content: vcpkg environment check results with timestamp

## Reporting

### Report Format

```markdown
# vcpkg Environment Check Report

**Date**: 2025-11-26 10:35:12

## vcpkg Installation

✅ **VCPKG_ROOT**: `C:\vcpkg`
✅ **Executable Path**: `C:\vcpkg\vcpkg.exe`
✅ **Version**: 2025-06-20-abc123def456
✅ **Toolchain File**: `C:\vcpkg\scripts\buildsystems\vcpkg.cmake` (exists)

### Version Status
⚠️ **Recommendation**: vcpkg-tool version 2025-06-20+ recommended. Current: 2024-06-15
Consider upgrading: https://github.com/microsoft/vcpkg-tool/releases

## Registry Configuration

✅ **Registry Root**: `C:\Users\user\vcpkg-registry`
✅ **Ports Folder**: `C:\Users\user\vcpkg-registry\ports` (exists)
✅ **Versions Folder**: `C:\Users\user\vcpkg-registry\versions` (exists)
✅ **Triplets Folder**: `C:\Users\user\vcpkg-registry\triplets` (exists)
✅ **Baseline File**: `C:\Users\user\vcpkg-registry\versions\baseline.json` (exists)

### vcpkg-configuration.json
✅ Found at: `C:\Users\user\vcpkg-registry\vcpkg-configuration.json`

## Environment Variables

| Variable | Value |
|----------|-------|
| `VCPKG_ROOT` | `C:\vcpkg` |
| `VCPKG_FEATURE_FLAGS` | `versions,registries` |
| `VCPKG_OVERLAY_PORTS` | (not set) |
| `VCPKG_OVERLAY_TRIPLETS` | (not set) |
| `VCPKG_BINARY_SOURCES` | (not set) |

### Feature Flags Explanation

`VCPKG_FEATURE_FLAGS=versions,registries`

- **versions**: Enables versioning support for precise dependency control
- **registries**: Enables custom registry support for private ports

## Status Summary

✅ vcpkg is properly configured for registry development
⚠️ Consider upgrading vcpkg-tool to 2025-06-20+

## Next Steps

Use absolute path for vcpkg if not in PATH: `C:\vcpkg\vcpkg.exe`
```

### When VCPKG_ROOT Not Set (Using Executable Path)

```markdown
## vcpkg Installation

⚠️ **VCPKG_ROOT**: Not set (using executable location)
✅ **Executable Path**: `C:\vcpkg\vcpkg.exe`
✅ **Inferred VCPKG_ROOT**: `C:\vcpkg`
```

### When vcpkg Not Found

```markdown
## vcpkg Installation

❌ **Error**: vcpkg not found

### Resolution Steps

1. **Check VCPKG_ROOT**: Ensure environment variable is set
   ```powershell
   $env:VCPKG_ROOT = "C:\path\to\vcpkg"
   ```

2. **Add to PATH**: Make vcpkg accessible
   ```powershell
   $env:PATH += ";C:\path\to\vcpkg"
   ```

3. **Install vcpkg**: If not installed
   ```powershell
   git clone https://github.com/microsoft/vcpkg
   cd vcpkg
   .\bootstrap-vcpkg.bat
   ```

4. **Searched Locations**:
   - `C:\vcpkg` (not found)
   - `C:\tools\vcpkg` (not found)
   - `C:\src\vcpkg` (not found)
```

## Work Note Entry

```markdown
## 2025-11-26 10:35:12 - /check-vcpkg-environment

✅ vcpkg environment verified
- VCPKG_ROOT: C:\vcpkg
- Version: 2025-06-20 (recommended)
- Registry structure: Valid
- Feature flags: versions, registries
```
