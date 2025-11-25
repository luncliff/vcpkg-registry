---
description: 'Detect and verify host system environment for vcpkg development'
agent: 'agent'
tools: ['runCommands/terminalLastCommand', 'runCommands/runInTerminal', 'fetch']
model: GPT-5 mini (copilot)
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
- Tool: `#runInTerminal`
- Windows: `$PSVersionTable.PSVersion`
- Linux/macOS: `uname -s`
- Purpose: Identify operating system family

#### Step 1.2: Get detailed system info
- Tool: `#runInTerminal`
- Windows: `Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsArchitecture`
- Linux: `uname -a; lsb_release -a 2>/dev/null || cat /etc/os-release`
- macOS: `sw_vers; uname -m`
- Purpose: Capture OS version and architecture

#### Step 1.3: Capture output
- Tool: `#terminalLastCommand`
- Purpose: Store system information for reporting

### Phase 2: Detect Shell Environment

#### Step 2.1: Identify active shell
- Tool: `#runInTerminal`
- Windows: `$PSVersionTable.PSEdition; $PSVersionTable.PSVersion`
- Linux/macOS: `echo $SHELL; $SHELL --version`
- Purpose: Determine shell type and version

#### Step 2.2: Check PowerShell minimum version (if applicable)
- Condition: Windows or PowerShell detected
- Requirement: PowerShell 7.1+
- Action: If below 7.1, issue warning but continue
- Tool: Parse version from previous output

#### Step 2.3: Test common development tools
- Tool: `#runInTerminal`
- Windows: `Get-Command git, cmake, curl -ErrorAction SilentlyContinue | Format-Table Name, Version`
- Linux/macOS: `command -v git cmake curl; git --version 2>/dev/null; cmake --version 2>/dev/null`
- Purpose: Check availability of common build tools

### Phase 3: Cross-Platform Translation (if non-Windows detected)

#### Step 3.1: Fetch GitHub Actions runner-images documentation
- Tool: `#fetch`
- URL: `https://github.com/actions/runner-images/tree/main/images`
- Purpose: Get standard environment configurations for reference

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

#### Step 4.2: Update work-note.md
- Tool: `#editFiles` (append mode)
- Content: Environment detection results with timestamp
- Purpose: Provide reproducible record

## Reporting

### Report Format

```markdown
# Environment Check Report

**Date**: 2025-11-26 10:30:45

## System Information

✅ **Operating System**: Windows 11 (Build 22631)
✅ **Architecture**: x64
✅ **Hostname**: dev-machine

## Shell Environment

✅ **Shell**: PowerShell Core (pwsh)
✅ **Version**: 7.4.0
✅ **Edition**: Core

## Development Tools

✅ **Git**: 2.43.0
✅ **CMake**: 3.28.1
✅ **Curl**: 8.5.0

## Status Summary

- ✅ System ready for vcpkg development
- ⚠️ Minimum PowerShell version (7.1+): Met (7.4.0)

## Cross-Platform Notes

Detected Windows environment. All commands shown will use PowerShell syntax.

For Bash/Zsh environments, use these equivalent commands:
- `$env:VCPKG_ROOT` → `$VCPKG_ROOT`
- `Get-ChildItem Env:` → `env | sort`
- `Test-Path <path>` → `[ -e <path> ] && echo true`
```

### For Non-Windows Environments

Additional section with command translations:

```markdown
## Command Translation Guide

Your system uses Bash/Zsh. Use these equivalents for PowerShell commands shown in prompts:

| PowerShell | Bash/Zsh |
|------------|----------|
| `$env:VAR` | `$VAR` |
| `Get-ChildItem Env:` | `env \| sort` |
| `Test-Path <path>` | `[ -e <path> ] && echo true` |
| `Get-Command vcpkg` | `command -v vcpkg` |
```

## Work Note Entry

```markdown
## 2025-11-26 10:30:45 - /check-environment

✅ Environment detected successfully
- OS: Windows 11 x64
- Shell: PowerShell 7.4.0
- Development tools: git, cmake, curl verified
```
