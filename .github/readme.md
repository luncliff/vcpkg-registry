# GitHub Copilot Custom Agents

This directory contains custom agent prompt files for GitHub Copilot to assist with vcpkg registry management tasks.

## What are Custom Agents?

Custom agents are repository-specific AI assistants configured through prompt files in the `.github/prompts/` directory. They provide specialized workflows for common vcpkg port development and maintenance tasks.

## Available Agents

### 1. `/check-environment`
**Purpose**: Detect and verify host system environment for vcpkg development

**When to use**:
- First-time vcpkg setup
- Troubleshooting environment issues
- Verifying cross-platform compatibility

**What it does**:
- Detects OS (Windows, Linux, macOS)
- Identifies shell (PowerShell, Bash, Zsh, CMD)
- Checks for required tools (Git, CMake, compilers)
- Auto-translates commands for different platforms
- Generates environment compatibility report

**Example usage**:
```
/check-environment
```

---

### 2. `/check-vcpkg-environment`
**Purpose**: Verify vcpkg installation, configuration, and registry structure

**When to use**:
- After cloning vcpkg-registry
- Before starting port development
- Troubleshooting vcpkg installation issues

**What it does**:
- Locates vcpkg installation (via `VCPKG_ROOT`)
- Validates vcpkg tool version
- Checks registry structure (ports/, versions/, triplets/)
- Verifies environment variables
- Explains vcpkg configuration options

**Example usage**:
```
/check-vcpkg-environment
```

---

### 3. `/search-port`
**Purpose**: Search for existing ports by name, URL, or keywords

**When to use**:
- Before creating a new port (check if it exists)
- Finding similar ports for reference
- Checking version differences between local and upstream

**What it does**:
- Searches local registry first (priority)
- Searches microsoft/vcpkg upstream
- Extracts port info from GitHub URLs
- Filters feature results (shows only ports)
- Identifies deprecated ports and alternatives
- Shows dependency information

**Example usage**:
```
/search-port openssl3
Search for ports related to https://github.com/pytorch/cpuinfo
Find tensorflow-lite port
```

---

### 4. `/create-port`
**Purpose**: Create a new vcpkg port with portfile.cmake, vcpkg.json, and patches

**When to use**:
- Adding a new library to the registry
- Creating experimental ports
- Porting libraries not in upstream vcpkg

**What it does**:
- Gathers project information (GitHub, homepage, license)
- Finds similar ports as templates
- Calculates SHA512 checksums for source archives
- Generates vcpkg.json with metadata
- Generates portfile.cmake with build instructions
- Creates usage file with CMake examples
- Validates port structure

**Example usage**:
```
/create-port https://github.com/pytorch/cpuinfo
Create port for openssl version 3.0.15
Generate port files for farmhash
```

---

### 5. `/install-port`
**Purpose**: Install vcpkg port with overlay-ports and analyze build logs

**When to use**:
- Testing newly created ports
- Verifying port changes
- Troubleshooting build failures

**What it does**:
- Parses port installation request (with features/triplets)
- Executes `vcpkg install` with overlay-ports
- Monitors terminal output for errors
- Analyzes build logs if installation fails
- Reports installation results with diagnostics
- Provides actionable fix recommendations

**Example usage**:
```
/install-port openssl3
Test cpuinfo port installation
Install opencv4[opengl,ffmpeg] with x64-windows triplet
```

---

### 6. `/review-port`
**Purpose**: Review port files against vcpkg guidelines and best practices

**When to use**:
- Before committing port changes
- Validating new ports
- Ensuring guideline compliance

**What it does**:
- Reads all port files (vcpkg.json, portfile.cmake, patches)
- Fetches vcpkg contribution guidelines
- Validates vcpkg.json structure (schema, version format)
- Validates portfile.cmake (helper functions, SHA512, copyright)
- Checks for required files (usage, copyright)
- Identifies violations and suggests fixes
- Generates comprehensive pass/fail report

**Example usage**:
```
/review-port openssl3
Check if tensorflow-lite follows guidelines
Validate cpuinfo port files
```

---

### 7. `/check-port-upstream`
**Purpose**: Check for upstream project updates and newer versions

**When to use**:
- Periodic maintenance checks
- Before upgrading ports
- Monitoring security updates

**What it does**:
- Reads current port version
- Fetches latest upstream release from project repository
- Checks microsoft/vcpkg for upstream version
- Compares versions (local vs. upstream vs. microsoft/vcpkg)
- Identifies version discrepancies
- Reports upgrade opportunities with release notes
- Calculates version age

**Example usage**:
```
/check-port-upstream openssl3
Is cpuinfo up to date?
Check for newer versions of tensorflow-lite
```

---

### 8. `/upgrade-port`
**Purpose**: Upgrade port to newer version with SHA512 calculation and testing

**When to use**:
- Updating ports to latest upstream version
- Applying security patches
- Testing version upgrades

**What it does**:
- Reads current port files
- Updates version in vcpkg.json
- Updates REF and SHA512 in portfile.cmake
- Downloads and calculates new SHA512
- Tests installation with `--editable` flag
- Validates changes
- Provides commit workflow instructions

**Example usage**:
```
/upgrade-port openssl3 to 3.0.15
Update cpuinfo to latest version
Upgrade tensorflow-lite to 2.14.1
```

## Workflow Patterns

### Creating a New Port

1. **Check if port exists**: `/search-port {project-name}`
2. **Create port**: `/create-port https://github.com/owner/repo`
3. **Test installation**: `/install-port {port-name}`
4. **Review for compliance**: `/review-port {port-name}`
5. **Commit and add to versions**:
   ```powershell
   git add ports/{port-name}/
   git commit -m "[{port-name}] add port version X.Y.Z"
   ./scripts/registry-add-version.ps1 -PortName "{port-name}"
   git add versions/
   git commit -m "[{port-name}] update baseline and version files"
   ```

### Upgrading an Existing Port

1. **Check for updates**: `/check-port-upstream {port-name}`
2. **Upgrade port**: `/upgrade-port {port-name} {new-version}`
3. **Test installation**: `/install-port {port-name}`
4. **Review changes**: `/review-port {port-name}`
5. **Commit and update versions** (same as above)

### Troubleshooting Port Issues

1. **Verify environment**: `/check-vcpkg-environment`
2. **Search for similar ports**: `/search-port {keyword}`
3. **Review port**: `/review-port {port-name}` (find violations)
4. **Test installation**: `/install-port {port-name}` (get build logs)
5. **Fix issues** (patches, portfile changes)
6. **Re-test**: `/install-port {port-name}`

## Configuration

These custom agents are configured to:
- **Use Claude Sonnet 4** as the default AI model (general-purpose, balanced)
- **Auto-translate commands** between PowerShell, Bash, and Zsh
- **Generate structured reports** with emoji indicators (✅ ⚠️ ❌)
- **Update work-note.md** with chronological task tracking
- **Follow vcpkg best practices** from microsoft/vcpkg guidelines

## Model Selection

Some agents use different AI models for optimization:

- **Simple prompts** (check-environment, check-vcpkg-environment): Can use GPT-4o mini for fast responses
- **Complex tasks** (create-port, upgrade-port): Use Claude Sonnet 4 for comprehensive reasoning

## Work Note Tracking

All agents and prompts will use `work-note.md`(located in the workspace root) in chronological order:

```markdown
## 2025-11-26 10:30:15 - /search-port

✅ Port search completed
- Query: openssl3
- Found in local registry: Yes (v3.0.15)
- Found in upstream: Yes (v3.0.13)
```

This provides a session log for tracking port development progress.

## Tool Access

Custom agents have access to:

- **Terminal execution**: `runInTerminal`, `terminalLastCommand`
- **File operations**: `readFile`, `createFile`, `editFiles`
- **Search**: `fileSearch`, `textSearch`, `codebase`
- **External data**: `fetch`, `githubRepo`
- **Navigation**: `listDirectory`

## Cross-Platform Support

All agents automatically translate commands for different environments:

**PowerShell** (Windows):
```powershell
$env:VCPKG_ROOT
Get-ChildItem ports/
```

**Bash/Zsh** (Linux/macOS):
```bash
$VCPKG_ROOT
ls -la ports/
```

## Contributing

When adding new custom agents:

1. Create `.github/prompts/{name}.prompt.md`
2. Include YAML frontmatter with `description`, `agent`, `tools`
3. Follow the structure: Goals → Workflow → Input → Process → Reporting
4. Update this README with agent description
5. Document in `docs/prompt-designs.md`

## References

- [GitHub Copilot Custom Agents Documentation](https://docs.github.com/en/copilot/using-github-copilot/using-custom-agents)
- [vcpkg Documentation](https://learn.microsoft.com/en-us/vcpkg/)
- [vcpkg Contribution Guidelines](https://github.com/microsoft/vcpkg/blob/master/CONTRIBUTING.md)
- [Repository Documentation](../docs/)

## License

These custom agent definitions are provided under CC0 1.0 Public Domain (same as the repository).
