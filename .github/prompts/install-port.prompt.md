---
description: 'Install vcpkg port with overlay-ports and analyze build logs'
agent: 'agent'
tools: ['edit/editFiles', 'search/fileSearch', 'search/readFile', 'runCommands/terminalLastCommand', 'runCommands/runInTerminal']
model: Claude Haiku 4.5 (copilot)
---

# Install Port

Execute vcpkg port installation with overlay-ports, monitor build process, and analyze results (success or failure).

## Prompt Goals

- Parse port installation request with features
- Execute `vcpkg install` with correct overlay-ports configuration
- Monitor terminal output for errors
- Analyze build logs if installation fails
- Report installation results with actionable recommendations
- Update work-note.md with installation status

## Workflow Expectation

**Default Behavior**: Executes installation autonomously, waits for completion, analyzes results.

**Stop Conditions**:
- Installation succeeds (report success)
- Installation fails (analyze logs, report errors)

**Prompt Forwarding**:
- If installation succeeds: User may proceed to `/review-port` for validation
- If installation fails: User may need to fix port files, then retry `/install-port`

## User Input

Extract installation request from natural language input:

**Supported Patterns**:
- Port names: `openssl3`, `tensorflow-lite`
- With features: `opencv4[opengl,ffmpeg]`
- With triplet: `zlib-ng:x64-windows`, `cpuinfo:arm64-android`
- Multiple ports: `openssl3 zlib-ng cpuinfo`
- Test with editable: `install openssl3 --editable` (for development)

**Examples**:
```
Install openssl3
Test cpuinfo port installation
Install opencv4[opengl] with x64-windows triplet
```

## Process

### Phase 1: Parse Installation Request

#### Step 1.1: Analyze user input
- Tool: Internal parsing
- Extract: Port names, features, triplet, editable flag

#### Step 1.2: Determine port location
- Check: Port exists in `ports/{port-name}/`
- Tool: `#fileSearch`
- Pattern: `ports/{port-name}/vcpkg.json`
- Purpose: Verify port is in local registry

#### Step 1.3: Validate triplet
- Condition: Custom triplet requested
- Check: Triplet file exists in `triplets/{triplet}.cmake`
- Fallback: Use default host triplet (x64-windows, x64-linux, arm64-osx)

#### Step 1.4: Check for features
- Tool: `#readFile`
- File: `ports/{port-name}/vcpkg.json`
- Purpose: Verify requested features exist in port manifest

### Phase 2: Pre-Installation Checks

#### Step 2.1: Verify VCPKG_ROOT environment variable
- Tool: `#runInTerminal`
- Command (PowerShell): `echo $env:VCPKG_ROOT`
- Command (Bash/Zsh): `echo $VCPKG_ROOT`
- Purpose: Ensure vcpkg installation accessible

#### Step 2.2: Check vcpkg version
- Tool: `#runInTerminal`
- Command: `vcpkg version`
- Purpose: Report vcpkg version for debugging

#### Step 2.3: Clean previous install (optional)
- Condition: User requested fresh install
- Tool: `#runInTerminal`
- Command (PowerShell): `Remove-Item -Recurse -Force "packages/{port-name}_*"`
- Command (Bash/Zsh): `rm -rf packages/{port-name}_*`
- Purpose: Remove cached packages

### Phase 3: Execute Installation

#### Step 3.1: Construct vcpkg install command
- Base command: `vcpkg install`
- Add: `--overlay-ports ./ports`
- Add (if custom triplet): `--overlay-triplets ./triplets --triplet {triplet}`
- Add (if editable): `--editable`
- Add (if custom roots): `--x-buildtrees-root buildtrees --x-packages-root packages --x-install-root installed`
- Add: Port specification with features

#### Step 3.2: Run vcpkg install
- Tool: `#runInTerminal`
- Command (example PowerShell):
  ```powershell
  vcpkg install --overlay-ports ./ports `
    --x-buildtrees-root buildtrees `
    --x-packages-root packages `
    --x-install-root installed `
    openssl3
  ```
- Command (example Bash/Zsh):
  ```bash
  vcpkg install --overlay-ports ./ports \
    --x-buildtrees-root buildtrees \
    --x-packages-root packages \
    --x-install-root installed \
    openssl3
  ```
- Wait: Installation completion (can take several minutes)

#### Step 3.3: Capture terminal output
- Tool: `#terminalLastCommand`
- Purpose: Get full installation log

### Phase 4: Analyze Results

#### Step 4.1: Check installation exit code
- Success: Exit code 0
- Failure: Non-zero exit code

#### Step 4.2: Parse installation output (if success)
- Search for: `Package openssl3:x64-windows is successfully installed`
- Extract: Installation time, dependencies built

#### Step 4.3: Analyze build logs (if failure)
- Tool: `#readFile`
- Files (check in order):
  1. `buildtrees/{port-name}/config-{triplet}-out.log`
  2. `buildtrees/{port-name}/install-{triplet}-out.log`
  3. `buildtrees/{port-name}/build-{triplet}-out.log`
- Search for: Error patterns (CMake errors, compiler errors, linker errors)

#### Step 4.4: Identify common error patterns
- CMake configuration errors: `CMake Error`, `Could NOT find`
- Compiler errors: `error C2XXX`, `error: ...`
- Linker errors: `unresolved external symbol`, `undefined reference`
- Missing dependencies: `Package ... is not installed`

#### Step 4.5: Extract error context
- Tool: `#readFile`
- Read: 20 lines before and after first error
- Purpose: Provide diagnostic context

### Phase 5: Post-Installation Verification (if success)

#### Step 5.1: Check installed files
- Tool: `#fileSearch`
- Pattern: `packages/{port-name}_*/` or `installed/{triplet}/`
- Purpose: Verify installation artifacts exist

#### Step 5.2: List installed headers
- Tool: `#runInTerminal`
- Command (PowerShell): `Get-ChildItem "installed/{triplet}/include/{port-name}*" -Recurse`
- Command (Bash/Zsh): `ls -R installed/{triplet}/include/{port-name}*`
- Purpose: Confirm header files installed

#### Step 5.3: List installed libraries
- Tool: `#runInTerminal`
- Command (PowerShell): `Get-ChildItem "installed/{triplet}/lib/*.lib"`
- Command (Bash/Zsh): `ls installed/{triplet}/lib/*.{a,so,dylib}`
- Purpose: Confirm library files built

#### Step 5.4: Check usage file
- Tool: `#readFile`
- File: `ports/{port-name}/usage`
- Purpose: Include usage instructions in report (if available)

### Phase 6: Generate Report

#### Step 6.1: Compile installation summary
- Status: Success or failure
- Duration: Installation time
- Errors: Error messages (if failed)
- Next steps: Recommendations

#### Step 6.2: Update work-note.md
- Tool: `#editFiles` (append mode)
- Content: Installation result with timestamp

## Reporting

The followings code snippets are example.

### Successful Installation

Suggest the next steps:

1. Review port with `/review-port openssl3` to validate against guidelines
2. Add version to registry: `./scripts/registry-add-version.ps1 -PortName "openssl3"`


### Installation with Features

### Installation Failed - CMake Configuration Error


### Installation Failed - Compiler Error

### Next Steps

1. Update `ports/cpuinfo/portfile.cmake` with fix
2. Retry installation: `/install-port cpuinfo`


### Installation Failed - Missing Patch


## Work Note Entry

### Success

```markdown
## 2025-11-26 12:05:30 - /install-port

✅ Installation successful
- Port: openssl3:x64-windows
- Duration: 2m 45s
- Dependencies: 2 built
- Output: installed/x64-windows/
- Next: Review port with /review-port
```

### Failure

```markdown
## 2025-11-26 12:15:45 - /install-port

❌ Installation failed
- Port: tensorflow-lite:x64-windows
- Error: Missing dependency (abseil)
- Log: buildtrees/tensorflow-lite/config-x64-windows-out.log
- Fix: Add abseil to vcpkg.json dependencies
- Retry: After fixing dependencies
```
