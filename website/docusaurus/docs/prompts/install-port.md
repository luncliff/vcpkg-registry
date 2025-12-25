---
description: 'Install vcpkg port with overlay-ports and analyze build logs'
agent: 'agent'
tools: ['execute/runInTerminal', 'read/readFile', 'read/terminalLastCommand', 'edit/createFile', 'edit/editFiles', 'search/fileSearch', 'todo']
model: GPT-5 mini (copilot)
---

# Install Port

Execute vcpkg port installation with overlay-ports, monitor build process, and analyze results (success or failure).

## Prompt Goals

- PASS: Port installed successfully with overlays; key checks validated; artifacts confirmed.
- FAIL: Install failed with clear error classification (CMake/compiler/linker/vcpkg configuration) and suggested next steps.

**Additional Goals**:
- Parse port installation request with features
- Execute `vcpkg install` with correct overlay-ports configuration
- Monitor terminal output for errors
- Analyze build logs if installation fails
- Report installation results with actionable recommendations

## Workflow Expectation

**Default Behavior**: Executes installation autonomously, waits for completion, analyzes results.

**Stop Conditions**:
- Installation succeeds (report success)
- Installation fails (analyze logs, report errors)

**Prompt Forwarding**:
- If installation succeeds: User may proceed to `/review-port` for validation
- If installation fails: User must fix port files, then retry `/install-port`

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
- Tool: #tool:search/fileSearch
- Pattern: `ports/{port-name}/vcpkg.json`
- Purpose: Verify port is in local registry

#### Step 1.3: Validate triplet
- Condition: Custom triplet requested
- Check: Triplet file exists in `triplets/{triplet}.cmake`
- Fallback: Use default host triplet (x64-windows, x64-linux, arm64-osx)

#### Step 1.4: Check for features
- Tool: #tool:read/readFile
- File: `ports/{port-name}/vcpkg.json`
- Purpose: Verify requested features exist in port manifest

### Phase 2: Pre-Installation Checks

#### Step 2.1: Verify VCPKG_ROOT environment variable
- Tool: #tool:execute/runInTerminal
- Command (PowerShell): `echo $env:VCPKG_ROOT`
- Command (Bash/Zsh): `echo $VCPKG_ROOT`
- Purpose: Ensure vcpkg installation accessible

#### Step 2.2: Check vcpkg version
- Tool: #tool:execute/runInTerminal
- Command: `vcpkg version`
- Purpose: Report vcpkg version for debugging

#### Step 2.3: Clean previous install (optional)
- Condition: User requested fresh install
- Tool: #tool:execute/runInTerminal
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
- Tool: #tool:execute/runInTerminal
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
- Tool: #tool:read/terminalLastCommand #tool:read/readFile 
- Purpose: Get full installation log

### Phase 4: Analyze Results

#### Step 4.1: Check installation exit code
- Success: Exit code 0
- Failure: Non-zero exit code

#### Step 4.2: Parse installation output (if success)
- Search for: `Package openssl3:x64-windows is successfully installed`
- Extract: Installation time, dependencies built

#### Step 4.3: Analyze build logs (if failure)
- Tool: #tool:read/readFile
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
- Tool: #tool:read/readFile
- Read: 20 lines before and after first error
- Purpose: Provide diagnostic context

### Phase 5: Post-Installation Verification (if success)

#### Step 5.1: Check installed files
- Tool: #tool:search/fileSearch
- Pattern: `packages/{port-name}_*/` or `installed/{triplet}/`
- Purpose: Verify installation artifacts exist

#### Step 5.2: List installed headers
- Tool: #tool:execute/runInTerminal
- Command (PowerShell): `Get-ChildItem "installed/{triplet}/include/{port-name}*" -Recurse`
- Command (Bash/Zsh): `ls -R installed/{triplet}/include/{port-name}*`
- Purpose: Confirm header files installed

#### Step 5.3: List installed libraries
- Tool: #tool:execute/runInTerminal
- Command (PowerShell): `Get-ChildItem "installed/{triplet}/lib/*.lib"`
- Command (Bash/Zsh): `ls installed/{triplet}/lib/*.{a,so,dylib}`
- Purpose: Confirm library files built

#### Step 5.4: Check usage file
- Tool: #tool:read/readFile
- File: `ports/{port-name}/usage`
- Purpose: Include usage instructions in report (if available)

### Phase 6: Generate Report

#### Step 6.1: Compile installation summary
- Status: Success or failure
- Duration: Installation time
- Errors: Error messages (if failed)
- Next steps: Recommendations

## Reporting

Replace example reports with a deterministic structure. The agent MUST output a markdown document with the headings below (in order). Every heading must appear; use `None` when no data. Keep bullets concise; avoid narrative paragraphs.

### Required Top-Level Headings
1. `# Port Installation Report`
2. `## Summary`
3. `## Command`
4. `## Result`
5. `## Artifacts`
6. `## Usage`
7. `## Errors` (only if failed; still emit if success → `None`)
8. `## Diagnostics` (log locations / key patterns)
9. `## Recommendations`
10. `## Next Steps`

### 1. Summary
- Port Specification: `<name>[features]:<triplet>` or `<name>:<triplet>`
- Timestamp: ISO 8601 UTC (`YYYY-MM-DD HH:MM:SS UTC`)
- Mode: `editable` | `standard`
- Outcome: `SUCCESS` | `FAILURE`
- Duration: `Xm Ys` or `unknown`

### 2. Command
Single fenced block with exact invocation used (powershell form). No explanatory text.

### 3. Result
- Status icon: ✅ success / ❌ failure
- Dependencies Built: count and primary names (max 5 then `+N more`)
- Features Enabled: list or `None`
- Cached Sources Used: yes/no (if parseable)

### 4. Artifacts (success only; if failure emit planned paths or `None`)
- Include Headers: path or `None`
- Libraries: list of produced libs (trim to first 5) or `None`
- Binaries: dll/so/dylib list (trim) or `None`

### 5. Usage
- If `usage` file exists: include its first 10 lines in fenced `cmake`
- Else if CMake config likely (installed `*.cmake` under `share/<port>`): emit generic `find_package(<Port> CONFIG REQUIRED)` snippet
- Else: `None`

### 6. Errors (failure case)
- Primary Error Type: `CMake`, `Compiler`, `Linker`, `Dependency`, `Platform`, `Unknown`
- First Error Line (verbatim)
- Count (approx if parsed) or `unknown`
Success case: `None`

### 7. Diagnostics
- Log Files Checked: list relative paths present
- Highlighted Patterns: bullet key tokens found (e.g., `Could NOT find`, `undefined reference`, `error C2065`)
- Missing Dependencies: list or `None`

### 8. Recommendations
Provide actionable fixes (failure) or follow-up (success). Bullets only:
- Failure: add missing dependency, patch suggestion, environment var export, triplet adjustment
- Success: review port, add version, run depend-info
If none: `None`

### 9. Next Steps
- Ordered short list; first item is highest priority
- Failure example order: Fix manifest → Re-run install → Consider patches
- Success example order: /review-port → add version → optional feature tests

### Post Report Action

If needed, users can include the installation summary in PR descriptions or issue reports for tracking purposes.

### Conventions
- Icons: ✅ success, ❌ failure, ⚠️ warning (non-blocking issues)
- Trim lists >5 items with ellipsis `... (+N more)`
- Do not dump entire build logs; reference path only
- All paths relative to workspace root
- Keep each bullet ≤120 characters

### Error Classification Rules
- CMake: contains `CMake Error` or `Could NOT find`
- Compiler: `error C` (MSVC) or `error:` (gcc/clang) lines
- Linker: `unresolved external symbol` / `undefined reference`
- Dependency: manifest missing required library detected in error
- Platform: environment/SDK variables missing (e.g., ANDROID_NDK_HOME)
- Unknown: none of the above matched

### Feature Handling
Parse feature spec inside brackets. If requested feature absent in manifest, classify as `Dependency` error and recommend manifest update.

### Non-Blocking Warnings
- Uppercase library filenames mismatch expected naming
- Absence of usage file when port installs only headers

This specification replaces prior example reports; emit only live execution data.

### References

Documents and Guides in this repository:

- [Guide: Create Port – Build Patterns](../../docs/guide-create-port-build.md)
- [Troubleshooting: Port Installation & Build Errors](../../docs/troubleshooting.md)
