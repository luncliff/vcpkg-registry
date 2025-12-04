---
description: 'Detect and verify host system environment for vcpkg development'
agent: 'agent'
tools: ['runCommands/terminalLastCommand', 'runCommands/runInTerminal', 'fetch', 'todos']
model: Claude Haiku 4.5 (copilot)
---

# Check Environment

Detect the host operating system, shell environment, and basic system configuration to ensure compatibility with vcpkg port development workflows.

## Prompt Goals

- Identify the operating system (Windows, Linux, macOS)
- Detect the active shell and its version (PowerShell, Bash, Zsh)
- Verify minimum required versions for development tools
- Provide cross-platform command translations when needed
- Generate a structured environment report for reproducibility

## Workflow Expectation

**Default Behavior**: This prompt runs autonomously and generates a comprehensive environment report. It automatically translates PowerShell commands to Bash/Zsh equivalents when non-Windows systems are detected.

**Stop Conditions**: 
- Execution completes successfully with full environment report
- PowerShell version below 7.1 detected (warning issued, execution continues)

**Prompt Forwarding**: No automatic forwarding. Users typically invoke `/check-vcpkg-environment` next.

## User Input

This prompt requires no user input arguments. It automatically detects the current environment.

## Process

### Phase 1: Detect Operating System

#### Step 1.1: Check OS type
- Tool: #tool:runCommands/runInTerminal
- Windows: `$PSVersionTable.PSVersion`
- Linux/macOS: `uname -s`
- Purpose: Identify operating system family

#### Step 1.2: Get detailed system info
- Tool: #tool:runCommands/runInTerminal
- Windows: `Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsArchitecture`
- Linux: `uname -a; lsb_release -a 2>/dev/null || cat /etc/os-release`
- macOS: `sw_vers; uname -m`
- Purpose: Capture OS version and architecture

#### Step 1.3: Capture output
- Tool: #tool:runCommands/terminalLastCommand
- Purpose: Store system information for reporting

### Phase 2: Detect Shell Environment

#### Step 2.1: Identify active shell
- Tool: #tool:runCommands/runInTerminal
- Windows: `$PSVersionTable.PSEdition; $PSVersionTable.PSVersion`
- Linux/macOS: `echo $SHELL; $SHELL --version`
- Purpose: Determine shell type and version

#### Step 2.2: Check PowerShell minimum version (if applicable)
- Condition: Windows or PowerShell detected
- Requirement: PowerShell 7.1+
- Action: If below 7.1, issue warning but continue
- Tool: Parse version from previous output

#### Step 2.3: Test common development tools
- Tool: #tool:runCommands/runInTerminal
- Purpose: Check availability and versions using an executable list with a command template

Command templates (the agent will iterate executables and apply the template):

- Windows (PowerShell):
  - Template: `Get-Command <exe> -ErrorAction SilentlyContinue | Select-Object Source`
  - Executables: `curl`, `tar`, `zip`, `unzip`, `git`, `cmake`, `ninja`

- Linux/macOS (POSIX shells):
  - Template: `command -v <exe>; <exe> --version 2>/dev/null`
  - Executables: `curl`, `tar`, `zip`, `unzip`, `git`, `cmake`, `ninja`

### Phase 3: Cross-Platform Translation (if non-Windows detected)

#### Step 3.1: Fetch GitHub Actions runner-images documentation
- Tool: #tool:fetch
- Purpose: Get standard environment configurations for reference
- URLs: Fetch the following links to lookup proper documents
  - https://github.com/actions/runner-images/blob/main/README.md
  - https://docs.github.com/en/actions/concepts/runners/github-hosted-runners

#### Step 3.2: Generate command translation guide
- Action: Create Bash/Zsh equivalents for PowerShell commands used in other prompts
- Examples:
  - PowerShell: `$env:VCPKG_ROOT` → Bash: `$VCPKG_ROOT`
  - PowerShell: `Get-ChildItem Env:` → Bash: `env | sort`
  - PowerShell: `Test-Path` → Bash: `[ -e <path> ] && echo "true" || echo "false"`

### Phase 4: Generate Report

#### Step 4.1: Compile environment summary
- Collect all detected information
- Format as structured markdown report

## Reporting

Replace example outputs with a deterministic specification.
The agent MUST emit a markdown report containing the headings below (in order). Emit all headings; if a section has no data write `None`.
Keep bullets concise (≤120 chars). Use tables only when listing >5 tools or >5 command translations.

### Required Top-Level Headings
1. `# Environment Check Report`
2. `## Summary`
3. `## System`
4. `## Shell`
5. `## Tools`
6. `## Cross-Platform Translations`
7. `## Status`
8. `## Recommendations`
9. `## Next Steps`

### 1. Summary
- Timestamp: ISO 8601 UTC (`YYYY-MM-DD HH:MM:SS UTC`)
- OS Family: `Windows` | `Linux` | `macOS`
- Architecture: `x64` | `arm64` | etc.
- Shell: name + version
- Outcome: `READY` | `WARN` | `ERROR`

### 2. System
- OS Detailed: version/build string
- Hostname: or `None`
- Kernel (Unix): `uname -r` or `None`
- Distribution (Linux): from `/etc/os-release` or `None`

### 3. Shell
- Shell Name: `PowerShell` | `bash` | `zsh` | other
- Version: parsed value
- Edition (PowerShell): `Desktop` | `Core` | `None`
- Minimum Requirement (PowerShell ≥7.1): met ✅ / unmet ❌ / not applicable

### 4. Tools
Reflect bootstrap requirements:
- Required (Unix): `curl`, `zip`, `unzip`, `tar`
- Optional (Unix): `cmake`, `ninja`, `git`
- Windows: `curl` is sufficient for bootstrap; others optional (`git`, `cmake`, `ninja`)
- python: version or `missing` (optional)
Report each detected tool as `version` or `missing`. If more than 5, use a table.

### 5. Cross-Platform Translations
Only emit if shell ≠ PowerShell OR user is on non-Windows:
Bullets mapping common PowerShell commands to bash/zsh equivalents:
- `$env:VAR` → `$VAR`
- `Get-ChildItem Env:` → `env | sort`
- `Test-Path <path>` → `[ -e <path> ]`
- `Get-Command name` → `command -v name`
- `Remove-Item path` → `rm -rf path`
If Windows/PowerShell: `None` (note PowerShell is native).

### 6. Status
- Readiness: one line summary (e.g., `All required tools present`)
- Warnings: list (e.g., outdated PowerShell, missing optional tool) or `None`
- Errors: blocking issues (missing git/cmake) or `None`

### 7. Recommendations
Prioritized actions:
- Install missing tools
- Upgrade PowerShell if <7.1
- Add optional tools (python) if port development requires
`None` if no actions.

### 8. Next Steps
Ordered list (max 5):
- If READY: suggest `/check-vcpkg-environment`
- If WARN: perform upgrades then re-run check
- If ERROR: install missing tools first

### Conventions
- Icons: ✅ present, ⚠️ warning, ❌ error
- Do not include full multi-line system dumps; extract key fields only
- All versions raw from tool output without extra parsing beyond first token

### Non-Blocking Warnings
- PowerShell version ≥7.0 but <7.1
- Missing optional tools (python) not strictly required

### Blocking Errors
- Shell detection failed (no command execution)

This specification replaces previous example reports; output only real environment data.
