# GitHub Copilot Custom Agent Design Document

This document summarizes the design decisions, structure, and rationale behind the 8 GitHub Copilot custom agents for vcpkg-registry management.

**Design Session Date**: 2025-11-26  
**GitHub Copilot AI Model**: Claude Sonnet 4 (default)

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [Agent Structure](#agent-structure)
3. [Design Decisions](#design-decisions)
4. [Agent Specifications](#agent-specifications)
5. [Workflow Patterns](#workflow-patterns)
6. [Implementation Notes](#implementation-notes)

---

## Design Philosophy

### Core Principles

1. **Autonomous Execution**: Agents work independently without requiring intermediate confirmations
2. **Cross-Platform Compatibility**: Auto-translate commands for PowerShell, Bash, Zsh
3. **Comprehensive Reporting**: Generate structured markdown reports with emoji indicators
4. **Guideline Compliance**: Follow microsoft/vcpkg contribution guidelines
5. **Experimental Flexibility**: Support private registry practices (embedded CMakeLists.txt, custom triplets)
6. **Transparent Tracking**: Append execution summaries to `work-note.md`

### User Experience Goals

- **Minimize friction**: Reduce repetitive manual tasks in port development
- **Provide clarity**: Generate detailed reports explaining what was done and why
- **Enable learning**: Include educational context (e.g., explaining vcpkg environment variables)
- **Support iteration**: Allow testing with `--editable` flag before committing changes
- **Prevent errors**: Validate port structure before installation

---

## Agent Structure

All 8 custom agents follow a consistent structure:

### YAML Frontmatter

```yaml
---
description: 'Short description of agent purpose'
agent: 'agent'
tools: ['runInTerminal', 'readFile', 'editFiles', 'fetch', ...]
---
```

**Properties**:
- `description`: Required string explaining agent purpose (shown in UI)
- `agent`: Set to `'agent'` string (agent mode)
- `tools`: Array of tool names the agent can use

### Markdown Body

Each agent's prompt follows this consistent structure:

#### 1. **Goals**
Clear bullet points stating what the agent aims to accomplish.

#### 2. **Workflow Expectation**
- **Default Behavior**: How the agent operates autonomously
- **Stop Conditions**: When the agent completes and yields back to user
- **Prompt Forwarding**: Suggested next agents in the workflow

#### 3. **User Input**
- **Supported Patterns**: Examples of natural language input the agent can parse
- **Examples**: Concrete usage examples

#### 4. **Process**
Multi-phase step-by-step execution plan:
- **Phase N: {Name}**: Logical grouping of related steps
  - **Step N.M: {Description}**: Specific action with tool usage
  - **Condition**: When this step applies
  - **Purpose**: Why this step is necessary

#### 5. **Reporting**
Multiple example reports showing different scenarios:
- Success cases
- Failure cases
- Edge cases (deprecated ports, major version upgrades, etc.)
- Work note entries

---

## Design Decisions

### 1. Why Custom Agents Instead of Simple Prompts?

**Decision**: Use GitHub Copilot custom agents (repository-level) instead of VS Code prompt files

**Rationale**:
- **Repository Context**: Agents have direct access to vcpkg-registry structure
- **Tool Access**: Can use runInTerminal, fetch, editFiles, fileSearch
- **Persistent Configuration**: Stored in `.github/prompts/` for team collaboration
- **Workflow Integration**: Can forward to other agents for multi-step tasks

---

### 2. Claude Sonnet 4 as Default Model

**Decision**: Use Claude Sonnet 4 (not Claude Haiku 4.5 or GPT-4o)

**Rationale**:
- **General-purpose coding**: Balanced performance for complex tasks
- **Comprehensive reasoning**: Handles multi-phase workflows
- **Good at structured output**: Generates consistent markdown reports
- **Cost-effective**: 1x multiplier (no premium charges)

**Alternative Models**:
- **GPT-5 mini**: Can be used for simple agents (check-environment, check-vcpkg-environment)
- **Claude Haiku 4.5**

---

### 3. Cross-Platform Command Translation

**Decision**: Always provide PowerShell, Bash, and Zsh command variants

**Rationale**:
- **User base diversity**: Windows (PowerShell), Linux/macOS (Bash/Zsh)
- **vcpkg compatibility**: vcpkg supports all major platforms
- **Android/iOS development**: Requires Linux/macOS for cross-compilation
- **Reduce friction**: Users don't need to manually translate commands

**Implementation**:
```markdown
**PowerShell**:
```powershell
$env:VCPKG_ROOT
```

**Bash/Zsh**:
```bash
$VCPKG_ROOT
```
```

---

### 4. Structured Markdown Reports with Emojis

**Decision**: Use emoji indicators (✅ ⚠️ ❌) in reports

**Rationale**:
- **Visual clarity**: Quick status identification
- **GitHub rendering**: Emojis render well in markdown
- **Consistent pattern**: Same emojis across all agents
- **Accessibility**: Supplemented with text (e.g., "✅ Success")

**Status Indicators**:
- ✅ = Success, completed, valid
- ⚠️ = Warning, needs attention, experimental
- ❌ = Error, failed, missing

---

### 5. Work Note Tracking Pattern

**Decision**: Append execution summaries to `work-note.md`

**Rationale**:
- **Session logging**: Track what agents did during development session
- **Debugging aid**: Review past actions when troubleshooting
- **Progress visibility**: See chronological port development history
- **Chronological append**: Never overwrite, only append with timestamp

**Format**:
```markdown
## 2025-11-26 10:30:15 - /agent-name

✅ Short status summary
- Key detail 1
- Key detail 2
- Next action
```

---

### 6. Experimental Features Support

**Decision**: Allow experimental practices (embedded CMakeLists.txt) with warnings

**Rationale**:
- **Private registry flexibility**: Not constrained by microsoft/vcpkg upstream rules
- **Rapid prototyping**: Faster iteration for complex ports
- **Clear warnings**: Document when approach differs from upstream guidelines
- **Upstream contribution path**: Provide guidance to convert experimental approaches to patches

**Example**:
```markdown
⚠️ **Warning**: This approach is for experimental/private registries only.

If contributing to microsoft/vcpkg upstream:
1. Convert embedded CMakeLists.txt to patch files
2. Use `vcpkg_apply_patches` instead of `file(COPY ...)`
```

---

### 7. Stop Conditions and Prompt Forwarding

**Decision**: Agents always suggest next steps but don't auto-forward

**Rationale**:
- **User control**: User decides when to proceed
- **Iterative development**: Allows fixing issues before next step
- **Clear workflow**: Documents recommended agent sequence
- **Prevent runaway execution**: Avoid cascading agent calls

**Pattern**:
```markdown
## Next Steps

Port created successfully. Test installation:
```powershell
/install-port {port-name}
```

After installation succeeds, review port:
```powershell
/review-port {port-name}
```
```

---

### 8. vcpkg Install Testing with `--editable`

**Decision**: `/upgrade-port` uses `--editable` flag for testing

**Rationale**:
- **Iterative fixes**: Allows fixing port without version conflicts
- **No registry pollution**: Doesn't add version to registry until committed
- **Recommended by Microsoft**: Official vcpkg documentation recommends for development
- **Faster iteration**: Skip version tracking for experimental changes

**Reference**: https://learn.microsoft.com/en-us/vcpkg/commands/install#editable-mode

---

## Agent Specifications

### 1. `/check-environment`

**Purpose**: Detect OS, shell, and development environment

**Phases**:
1. Detect OS (Windows, Linux, macOS)
2. Identify shell (PowerShell, Bash, Zsh, CMD)
3. Check development tools (Git, CMake, compilers)

**Key Features**:
- Auto-translates commands for detected shell
- Provides installation instructions for missing tools
- Generates compatibility report

**Stop Condition**: Environment report generated

---

### 2. `/check-vcpkg-environment`

**Purpose**: Verify vcpkg installation and registry structure

**Phases**:
1. Locate vcpkg installation
2. Validate vcpkg tool version
3. Check registry structure
4. Verify environment variables
5. Generate report with explanations

**Key Features**:
- Explains `VCPKG_ROOT`, `VCPKG_OVERLAY_PORTS`, `VCPKG_FEATURE_FLAGS`
- Validates registry folder structure (ports/, versions/, triplets/)
- Checks `vcpkg-configuration.json`

**Stop Condition**: Vcpkg environment validated

---

### 3. `/search-port`

**Purpose**: Find existing ports by name, URL, or keywords

**Phases**:
1. Parse search input (extract port names from URLs)
2. Search local registry (priority)
3. Search microsoft/vcpkg upstream
4. Check project homepage
5. Get dependency information
6. Generate report

**Key Features**:
- Filters feature results (shows only ports)
- Identifies deprecated ports
- Compares local vs. upstream versions
- Extracts port info from GitHub URLs

**Stop Condition**: Search results compiled

**Prompt Forwarding**:
- If port exists: `/install-port` or `/review-port`
- If port doesn't exist: `/create-port`

---

### 4. `/create-port`

**Purpose**: Generate new port with portfile.cmake, vcpkg.json, patches

**Phases**:
1. Gather project information (GitHub, license, dependencies)
2. Find template ports (similar build systems)
3. Calculate SHA512 checksums
4. Generate port files (vcpkg.json, portfile.cmake, usage)
5. Validate port structure

**Key Features**:
- Downloads source archive and calculates SHA512
- Finds similar ports as templates
- Supports embedded CMakeLists.txt approach (with warnings)
- Provides placeholder SHA512 strategy (use `0`, then get correct value from vcpkg error)

**Stop Condition**: Port files created and validated

**Prompt Forwarding**: Always forward to `/install-port` for testing

---

### 5. `/install-port`

**Purpose**: Execute vcpkg install with overlay-ports and analyze logs

**Phases**:
1. Parse installation request (port, features, triplet)
2. Pre-installation checks (VCPKG_ROOT, vcpkg version)
3. Execute installation (with overlay-ports)
4. Analyze results (success or failure)
5. Post-installation verification (check installed files)
6. Generate report

**Key Features**:
- Parses features syntax (`opencv4[opengl,ffmpeg]`)
- Monitors terminal output for errors
- Analyzes build logs on failure (CMake errors, compiler errors, linker errors)
- Provides actionable fix recommendations

**Stop Condition**: Installation completed (success or failure)

**Prompt Forwarding**:
- If success: `/review-port` for validation
- If failure: User fixes issues, then retry `/install-port`

---

### 6. `/review-port`

**Purpose**: Validate port against vcpkg guidelines

**Phases**:
1. Locate port files (vcpkg.json, portfile.cmake, patches)
2. Fetch vcpkg guidelines (microsoft/vcpkg CONTRIBUTING.md, maintainer guide)
3. Validate vcpkg.json (schema, version format, dependencies)
4. Validate portfile.cmake (helper functions, SHA512, copyright)
5. Validate additional files (usage, patches, embedded CMakeLists.txt)
6. Cross-reference with baseline
7. Generate pass/fail report

**Key Features**:
- Checks for deprecated functions (`vcpkg_fixup_cmake_targets`)
- Validates SPDX license identifiers
- Warns about experimental features (embedded CMakeLists.txt)
- Suggests fixes for violations

**Stop Condition**: Review report generated

**Prompt Forwarding**:
- If pass: User commits changes and runs `registry-add-version.ps1`
- If fail: User fixes violations and re-runs `/review-port`

---

### 7. `/check-port-upstream`

**Purpose**: Monitor upstream project for new releases

**Phases**:
1. Read current port version
2. Fetch latest upstream release (GitHub releases, tags)
3. Check microsoft/vcpkg upstream version
4. Compare versions (local, upstream project, microsoft/vcpkg)
5. Check for breaking changes (CHANGELOG.md)
6. Generate version comparison report

**Key Features**:
- Normalizes version formats (strip 'v', project prefixes)
- Calculates version age (days since release)
- Detects major version bumps (warns about breaking changes)
- Includes release notes links

**Stop Condition**: Version check completed

**Prompt Forwarding**:
- If newer version: `/upgrade-port` to update
- If up-to-date: No action needed

---

### 8. `/upgrade-port`

**Purpose**: Update port to newer version with SHA512 and testing

**Phases**:
1. Analyze current port (version, REF, SHA512)
2. Gather new version information
3. Calculate new SHA512 (download source archive)
4. Update port files (vcpkg.json, portfile.cmake)
5. Test with `--editable` flag
6. Handle test results (SHA512 correction, build errors)
7. Validate file changes
8. Generate upgrade report

**Key Features**:
- Auto-detects REF format (v${VERSION}, openssl-${VERSION}, etc.)
- Handles SHA512 calculation failures (placeholder strategy)
- Tests with `--editable` for iterative fixes
- Warns about major version upgrades
- Provides rollback commands on failure

**Stop Condition**: Port upgraded and tested (success or failure)

**Prompt Forwarding**:
- If success: User commits and runs `registry-add-version.ps1`
- If failure: User fixes build errors and retries `/install-port`

---

## Workflow Patterns

### Pattern 1: Creating a New Port

```
/search-port {project-name}
  ↓
/create-port https://github.com/owner/repo
  ↓
/install-port {port-name}
  ↓
/review-port {port-name}
  ↓
[User commits changes]
  ↓
[User runs registry-add-version.ps1]
```

### Pattern 2: Upgrading an Existing Port

```
/check-port-upstream {port-name}
  ↓
/upgrade-port {port-name} {new-version}
  ↓
/install-port {port-name}
  ↓
/review-port {port-name}
  ↓
[User commits changes]
  ↓
[User runs registry-add-version.ps1]
```

### Pattern 3: Troubleshooting Port Issues

```
/check-vcpkg-environment
  ↓
/search-port {keyword}  (find similar working ports)
  ↓
/review-port {port-name}  (find violations)
  ↓
/install-port {port-name}  (get build logs)
  ↓
[User fixes issues: patches, portfile changes]
  ↓
/install-port {port-name}  (re-test)
```

---

## Implementation Notes

### Tool Usage Patterns

| Tool | Usage |
|------|-------|
| `runInTerminal` | Execute vcpkg commands, calculate SHA512, run git |
| `terminalLastCommand` | Capture terminal output after command execution |
| `readFile` | Read port files (vcpkg.json, portfile.cmake) |
| `editFiles` | Update port files, append to work-note.md |
| `createFile` | Generate new port files |
| `fileSearch` | Find port directories, list installed files |
| `textSearch` | Search baseline.json, grep for patterns |
| `fetch` | Get upstream releases, GitHub repo info, guidelines |
| `githubRepo` | Search microsoft/vcpkg for ports |
| `listDirectory` | List folder contents |

### Error Handling Strategy

1. **Graceful degradation**: If tool fails, try alternative approach
2. **Clear error messages**: Explain what went wrong and why
3. **Actionable recommendations**: Provide specific fix instructions
4. **Rollback guidance**: Show how to undo changes if needed

### Reporting Standards

All reports follow this structure:

```markdown
# {Agent Name} Report

**Port**: `{port-name}`
**Date**: {timestamp}

## {Section 1}

✅/⚠️/❌ Status summary

### Details
- Key point 1
- Key point 2

## Next Steps

Actionable instructions with commands
```

### Work Note Format

```markdown
## {timestamp} - /{agent-name}

✅/⚠️/❌ Short status summary
- Key detail 1
- Key detail 2
- Next action
```

---

## Design Session Summary

This document captures the comprehensive design session where 18 clarification questions were answered to establish the agent behavior patterns:

### Key Questions Addressed

1. **Cross-platform support**: Auto-translate PowerShell ↔ Bash/Zsh
2. **Error handling**: Always provide actionable recommendations
3. **Tool restrictions**: Use only available GitHub Copilot tools
4. **Workflow forwarding**: Suggest next steps but don't auto-execute
5. **Autonomous execution**: Work without intermediate confirmations
6. **Experimental features**: Support with clear warnings
7. **Reporting format**: Structured markdown with emojis
8. **Model selection**: Claude Sonnet 4 (default), GPT-4o mini (simple tasks)
9. **Version control**: Use `--editable` for testing before commits
10. **Guideline compliance**: Follow microsoft/vcpkg best practices

### Design Iteration Process

1. **Requirements gathering**: User provided 18 detailed answers
2. **Documentation research**: Fetched 6 GitHub Copilot documentation pages
3. **File creation**: Generated 8 custom agent files
4. **YAML correction**: Fixed deprecated `mode` property → `agent`
5. **Documentation**: Created README and this design document

---

## Future Enhancements

Potential additions to the agent system:

1. **/batch-check-upstream**: Check multiple ports for updates simultaneously
2. **/generate-patch**: Create patch files from embedded CMakeLists.txt
3. **/test-triplet**: Test port with custom triplet (Android, iOS)
4. **/sync-upstream**: Pull latest port from microsoft/vcpkg
5. **/dependency-graph**: Visualize port dependency tree

---

## References

- [GitHub Copilot Custom Agents Documentation](https://docs.github.com/en/copilot/using-github-copilot/using-custom-agents)
- [vcpkg Documentation](https://learn.microsoft.com/en-us/vcpkg/)
- [vcpkg Contribution Guidelines](https://github.com/microsoft/vcpkg/blob/master/CONTRIBUTING.md)
- [vcpkg Maintainer Guide](https://github.com/microsoft/vcpkg-docs/blob/main/vcpkg/contributing/maintainer-guide.md)
- [Repository Copilot Instructions](../.github/copilot-instructions.md)

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-26  
**Authors**: GitHub Copilot (Claude Sonnet 4)
