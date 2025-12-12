---
description: 'Upgrade port to newer version with SHA512 calculation and testing'
agent: 'agent'
tools: ['execute/runInTerminal', 'read/readFile', 'read/terminalLastCommand', 'edit/createFile', 'edit/editFiles', 'search/fileSearch', 'web/fetch', 'todo']
model: Claude Sonnet 4 (copilot)
---

# Upgrade Port

Update existing port to newer upstream version by modifying vcpkg.json and portfile.cmake, calculating new SHA512, and testing with --editable flag.

## Prompt Goals

- Read current port files (vcpkg.json, portfile.cmake)
- Update version in vcpkg.json
- Update REF and SHA512 in portfile.cmake
- Calculate new SHA512 for source archive
- Test installation with `--editable` flag
- Generate upgrade report with validation results
- Update work-note.md

## Workflow Expectation

**Default Behavior**: Autonomously reads port files, updates version/SHA512, tests with --editable, and reports results.

**Stop Conditions**:
- Port upgraded and tested successfully
- Port upgraded but test failed (report errors for user to fix)

**Prompt Forwarding**:
- If upgrade test succeeds: User should commit changes and run `./scripts/registry-add-version.ps1`
- If upgrade test fails: User must fix issues and retry `/vcpkg-registry.install-port`

## User Input

Extract port name and target version from natural language input:

**Supported Patterns**:
- Port name with version: `openssl3 3.0.15`, `upgrade cpuinfo to 2024-01-15`
- Without version: `upgrade tensorflow-lite` (fetch latest from upstream)
- With URL: `upgrade openssl3 from https://github.com/openssl/openssl/releases/tag/openssl-3.0.15`

**Examples**:
```
Upgrade openssl3 to 3.0.15
Update cpuinfo to latest version
Upgrade tensorflow-lite to 2.14.1
```

## Process

### Phase 1: Analyze Current Port

#### Step 1.1: Read current vcpkg.json
- Tool: #tool:read/readFile
- File: `ports/{port-name}/vcpkg.json`
- Extract: Current `version`, `homepage`

#### Step 1.2: Read current portfile.cmake
- Tool: #tool:read/readFile
- File: `ports/{port-name}/portfile.cmake`
- Extract: `REPO` (GitHub owner/repo), `REF`, `SHA512`, `HEAD_REF`

#### Step 1.3: Determine target version
- Condition: Version specified in user input
  - Use: Specified version
- Condition: Version not specified
  - Action: Fetch latest release from upstream (use `/vcpkg-registry.check-port-upstream` logic)
  - Tool: #tool:web/fetch
  - URL: `{homepage}/releases/latest` or `https://api.github.com/repos/{owner}/{repo}/releases/latest`

### Phase 2: Gather New Version Information

#### Step 2.1: Normalize target version
- Strip: Leading 'v' if present (`v3.0.15` → `3.0.15`)
- Strip: Project name prefix (`openssl-3.0.15` → `3.0.15`)
- Format: Match vcpkg version format (semver or date)

#### Step 2.2: Construct source URL
- Pattern (GitHub): `https://github.com/{owner}/{repo}/archive/refs/tags/{tag}.tar.gz`
- Tag format: Use original upstream tag (may have 'v' prefix or project name)
- Example: `https://github.com/openssl/openssl/archive/refs/tags/openssl-3.0.15.tar.gz`

#### Step 2.3: Determine REF value
- Check: Does upstream use version tags with 'v' prefix?
- Check: Does upstream use project-name prefix?
- Examples:
  - `v${VERSION}` for projects using `v1.2.3` tags
  - `openssl-${VERSION}` for OpenSSL
  - `${VERSION}` for simple tags

### Phase 3: Calculate New SHA512

#### Step 3.1: Download source archive
- Tool: #tool:execute/runInTerminal
- Command (PowerShell):
  ```powershell
  $Version = "{target-version}"
  $Url = "{constructed-source-url}"
  curl -L -o "temp-${Version}.tar.gz" $Url
  ```
- Command (Bash/Zsh):
  ```bash
  version="{target-version}"
  url="{constructed-source-url}"
  curl -L -o "temp-${version}.tar.gz" "$url"
  ```
- Wait: Download completion

#### Step 3.2: Calculate SHA512
- Tool: #tool:execute/runInTerminal
- Command (PowerShell):
  ```powershell
  (Get-FileHash -Algorithm SHA512 "temp-${Version}.tar.gz").Hash.ToLower()
  ```
- Command (Bash/Zsh):
  ```bash
  sha512sum "temp-${version}.tar.gz" | awk '{print $1}'
  ```
- Capture: 128 character lowercase hex string

#### Step 3.3: Verify SHA512 format
- Check: Exactly 128 hex characters
- Check: Lowercase format (vcpkg preference)
- Purpose: Prevent malformed SHA512 values

#### Step 3.4: Clean up downloaded archive
- Tool: #tool:execute/runInTerminal
- Command (PowerShell): `Remove-Item "temp-${Version}.tar.gz"`
- Command (Bash/Zsh): `rm "temp-${version}.tar.gz"`

#### Step 3.5: Handle download failure
- Fallback: Use SHA512 value `0` as placeholder
- Note: vcpkg will report correct SHA512 on first install attempt
- User action: Update SHA512 after test installation

### Phase 4: Update Port Files

#### Step 4.1: Update vcpkg.json version
- Tool: #tool:edit/editFiles
- File: `ports/{port-name}/vcpkg.json`
- Change: `"version": "{old-version}"` → `"version": "{new-version}"`
- Preserve: All other fields unchanged

#### Step 4.2: Update portfile.cmake REF
- Tool: #tool:edit/editFiles
- File: `ports/{port-name}/portfile.cmake`
- Change: `REF {old-ref}` → `REF {new-ref}`
- Common patterns:
  - `REF v${VERSION}` (no change needed if using variable)
  - `REF openssl-${VERSION}` (no change needed)
  - `REF v1.2.3` → `REF v{new-version}` (hardcoded, needs update)

#### Step 4.3: Update portfile.cmake SHA512
- Tool: #tool:edit/editFiles
- File: `ports/{port-name}/portfile.cmake`
- Change: `SHA512 {old-sha512}` → `SHA512 {new-sha512}`
- Ensure: 128 lowercase hex characters

#### Step 4.4: Review other version references
- Check: Are there version numbers in comments?
- Check: Are there hardcoded version numbers in OPTIONS?
- Update: Any version-specific configuration if needed

### Phase 5: Test Upgrade with --editable

#### Step 5.1: Explain --editable flag
- Purpose: Test port changes without committing to registry
- Behavior: Allows iterative fixes without version registry conflicts
- Documentation: https://learn.microsoft.com/en-us/vcpkg/commands/install#editable-mode

#### Step 5.2: Run vcpkg install with --editable
- Tool: #tool:execute/runInTerminal
- Command (PowerShell):
  ```powershell
  vcpkg install --editable `
    --overlay-ports ./ports `
    --x-buildtrees-root buildtrees `
    --x-packages-root packages `
    --x-install-root installed `
    {port-name}
  ```
- Command (Bash/Zsh):
  ```bash
  vcpkg install --editable \
    --overlay-ports ./ports \
    --x-buildtrees-root buildtrees \
    --x-packages-root packages \
    --x-install-root installed \
    {port-name}
  ```
- Wait: Installation completion (may take several minutes)

#### Step 5.3: Capture test results
- Tool: #tool:read/terminalLastCommand
- Purpose: Get full installation log

#### Step 5.4: Analyze test results
- Success: Exit code 0, "successfully installed" message
- Failure: Non-zero exit code, error messages
- If failed: Read build logs (same as `/vcpkg-registry.install-port` Phase 4)

### Phase 6: Handle Test Results

#### Step 6.1: If test succeeds
- Action: Prepare for version commit
- Next steps: User commits changes and runs `registry-add-version.ps1`

#### Step 6.2: If test fails with SHA512 error
- Check: Error message contains "SHA512 mismatch"
- Action: Extract correct SHA512 from error message
- Tool: #tool:edit/editFiles
- Update: portfile.cmake with correct SHA512
- Retry: Run test installation again

#### Step 6.3: If test fails with build errors
- Action: Analyze build logs (use `/vcpkg-registry.install-port` logic)
- Report: Common error patterns
- Suggest: Port may need patches for new version
- Next: User must fix build issues

#### Step 6.4: Check for breaking changes
- Condition: Major version upgrade or build failures
- Suggest: Review upstream changelog
- Suggest: May need new patches or portfile adjustments

### Phase 7: Validate File Changes

#### Step 7.1: Re-read updated vcpkg.json
- Tool: #tool:read/readFile
- File: `ports/{port-name}/vcpkg.json`
- Verify: Version updated correctly

#### Step 7.2: Re-read updated portfile.cmake
- Tool: #tool:read/readFile
- File: `ports/{port-name}/portfile.cmake`
- Verify: SHA512 updated correctly
- Verify: REF updated if needed

#### Step 7.3: Run format-manifest (optional)
- Tool: #tool:execute/runInTerminal
- Command:
  ```powershell
  ./scripts/registry-format.ps1 -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
  ```
- Purpose: Ensure vcpkg.json formatting correct

### Phase 8: Generate Upgrade Report

#### Step 8.1: Compile upgrade summary
- List: Version change, SHA512 change, test results
- Include: Any errors or warnings

#### Step 8.2: Update work-note.md
- Tool: #tool:edit/editFiles (append mode)
- Content: Upgrade details with timestamp

## Reporting

Replace example-rich outputs with a deterministic upgrade specification. The agent MUST emit a markdown report with the exact headings below (in order). Provide concise factual bullets; omit narrative fluff. If a section has no content, write `None`.

### Required Top-Level Headings
1. `# Port Upgrade Report`
2. `## Summary`
3. `## Version Changes`
4. `## Source & SHA512`
5. `## File Modifications`
6. `## Test Installation`
7. `## Validation`
8. `## Issues & Warnings`
9. `## Next Steps`

### 1. Summary
- Port: `<name>`
- Old Version: `<old>`
- New Version: `<new>`
- Timestamp: ISO 8601 UTC (`YYYY-MM-DD HH:MM:SS UTC`)
- Outcome: `SUCCESS` | `FAILURE` | `MAJOR VERSION WARNING` | `SHA512 CORRECTED`
- Mode: `editable test passed` | `editable test failed`

### 2. Version Changes
- vcpkg.json: `version` changed (old → new)
- REF Strategy: describe pattern used (`v${VERSION}` / `${VERSION}` / `<name>-${VERSION}`)
- Major/Minor bump classification; if major, flag with ⚠️

### 3. Source & SHA512
- Source Tag/Archive URL used
- SHA512 New: 128 hex chars (validate length) ✅/❌
- SHA512 Acquisition Method: direct download | reported by vcpkg mismatch correction
- Placeholder Used: yes/no (if `0` initially)
- Correction Applied: yes/no

### 4. File Modifications
List only changed lines/keys:
- `vcpkg.json`: version field updated ✅/❌
- `portfile.cmake`: REF updated (yes/no), SHA512 updated (yes/no)
- Additional version occurrences updated (if any) or `None`

### 5. Test Installation
- Command Executed (single line)
- Result: success/failure
- Duration (if parseable)
- Key Artifacts Installed: headers | libs | dlls (list or `None`)
- Build Log Path (relative) for failure

### 6. Validation
- Version field integrity ✅/❌
- SHA512 integrity ✅/⚠️ (uppercase warning) / ❌ (bad length)
- REF pattern consistency ✅/⚠️ (hardcoded tag) / ❌
- Editable mode test: passed/failed
- Baseline update required: yes/no

### 7. Issues & Warnings
Separate subsections:
- Critical Issues: block upgrade (build failure, invalid SHA512, missing source)
- Warnings: non-blocking (uppercase SHA512, hardcoded REF, placeholder used then fixed)
Provide each with brief fix action snippet (JSON/CMake or command).

### 8. Next Steps
Branch by outcome:
- SUCCESS: commit changes → run `registry-add-version.ps1` → commit versions
- SHA512 CORRECTED: retest then commit
- FAILURE: analyze logs; consider patches; optional rollback commands
- MAJOR VERSION WARNING: choose (proceed | create alternate port | revert)
Bulleted actionable items only.

### Post Report Action: Work Note Update

Use #tool:edit/createFile or #tool:edit/editFiles when appending to work-note.md.

```
## <timestamp UTC> - /vcpkg-registry.upgrade-port <port>
Outcome: SUCCESS|FAILURE|MAJOR|SHA512-CORRECTED
Old→New: <old> → <new>
SHA512: updated|placeholder|corrected
Test: passed|failed
Critical: <count>
Warnings: <count>
Next: <primary action>
```

### 10. Conventions
- Icons: ✅ valid, ⚠️ warning, ❌ error
- Keep bullets ≤120 chars
- Avoid full log dumps; reference path only
- Show at most first 16 chars of old/new SHA512 when contrasting (`old: abcdef...`) unless invalid

### Multi-Port (rare)
If future extension allows multi-port upgrade, repeat sections 2–7 per port with a shared Summary aggregate.

### Non-Blocking Conditions
- Placeholder SHA512 later corrected → classify as warning, not critical
- Hardcoded REF acceptable if upstream tag pattern inconsistent; still warn

This specification replaces prior sample reports. Generate only real execution data.

### References

Documents and Guides in this repository:

- [Guide: Updating an Existing Port](../../docs/guide-update-port.md)
- [Guide: Version Management for Port Updates](../../docs/guide-update-port-versioning.md)
- [Port Change Review Checklist](../../docs/review-checklist.md)
