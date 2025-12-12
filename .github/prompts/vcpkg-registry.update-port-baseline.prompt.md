---
description: 'Register new port versions into registry baseline and versions files'
agent: 'agent'
tools: ['execute/getTerminalOutput', 'execute/runInTerminal', 'read/readFile', 'read/terminalLastCommand', 'search/fileSearch', 'todo']
model: GPT-5 mini (copilot)
---

# Update Port Baseline

Register one or more ports into the registry `versions/` tracking using the helper script `./scripts/registry-add-version.ps1`. Falls back to inferring ports from recent chat when explicit names are not provided.

## Prompt Goals

- Accept port names (single or multiple) or infer from session context
- Validate ports exist in `ports/` folder
- Run `registry-add-version.ps1` for each port
- Capture and summarize script output
- Create a commit for baseline/version changes

## Workflow Expectation

**Default Behavior**: If no ports are provided, infer likely targets from recent conversation (e.g., last discussed port). Executes the add-version script per port and generates a concise report.

**Stop Conditions**:
- Baseline/version files updated for all requested ports
- Errors reported with actionable fixes

**Prompt Forwarding**:
- After success: Suggest `vcpkg format-manifest` and opening a PR
- On failure: Recommend fixing port files or verifying `VCPKG_ROOT`

## User Input

Supported patterns:
- Single port name: `openssl3`
- Multiple ports: `onnx onnx-optimizer onnxruntime`
- Natural language: `update baseline for ruy and cpuinfo`
- Empty input: infer from session chat (last referenced ports) or infer from latest 3 git commit logs

Examples:
```
Update baseline for miniaudio
Register versions for onnx, farmhash, dlpack
Add version entry for tensorflow-lite
```

## Process

### Phase 1: Determine Target Ports

#### Step 1.1: Parse explicit input
- If user provides names, use them directly.

#### Step 1.2: Infer from chat history or git logs
- Tool: #tool:execute/getTerminalOutput
- If no names, extract last discussed ports from recent messages.
- If recent messages lack port names, analyze last 3 git commit messages for port references.
- Heuristics: filenames like `ports/<name>/...`, mentions like `upgrade <name>`.

#### Step 1.3: Validate existence
- Tool: #tool:search/fileSearch
- Check `ports/{name}/vcpkg.json` exists.
- If missing, report and skip that name.

#### Step 1.4: Format the port files
- Tool: #tool:execute/runInTerminal
- Command (PowerShell):
  ```powershell
  ./scripts/registry-format.ps1 -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
  ```

### Phase 2: Execute Registry Add-Version

#### Step 2.1: Commit if files in ports folder changed
- Tool: #tool:execute/runInTerminal
- Command (PowerShell):
  ```powershell
  git add ./ports/port-name/
  git commit -m "[port-name] commit formatting changes"
  ```

#### Step 2.2: Run script per port
- Tool: #tool:execute/runInTerminal
- Command (PowerShell):
```powershell
$RegistryRoot = (Get-Location).Path
$VcpkgRoot = $env:VCPKG_ROOT
foreach ($p in $Ports) {
  ./scripts/registry-add-version.ps1 -PortName $p -VcpkgRoot $VcpkgRoot -RegistryRoot $RegistryRoot
}
```

#### Step 2.3: Capture output
- Tool: #tool:execute/getTerminalOutput
- Collect success lines and any errors from terminal.

### Phase 3: Results & Recommendations

#### Step 3.1: Summarize changes
- List updated files under `versions/` (including `baseline.json`).

#### Step 3.2: Create commit for versions folder changes
- Tool: #tool:execute/runInTerminal
- Commit changes:
```powershell
git add ./versions
git commit -m "[<port-name>] update baseline"
```

## Error Handling

- Missing `vcpkg` or CLI tool execution error: print instructions to run [/check-vcpkg-environment](./check-vcpkg-environment.prompt.md)
- Port unknown: suggest checking name or creating the port.
- Script failure: show last terminal output and diagnose the terminal output messages.

## Reporting

Emit a markdown report with the headings below (in order). If a section has no data, write `None`.

1. `# Update Baseline Report`
2. `## Summary`
3. `## Ports`
5. `## Changes`
6. `## Errors`
7. `## Recommendations`
8. `## Next Steps`

### Summary
- Timestamp: ISO 8601 UTC
- Ports Requested: list
- Ports Processed: list
- Outcome: `READY` | `WARN` | `ERROR`

### Ports
- Valid: names found in `ports/`
- Invalid: names missing or unresolved

### Changes
- Updated files: `versions/<letter>-/<port>.json`, `versions/baseline.json`

### Errors
- List of failures with brief context

### Next Steps
- Open PR and link to upstream release notes

### References

Documents and Guides in this repository:

- [Guide: Updating an Existing Port](../../docs/guide-update-port.md): Step 5 "Format and Register"
- [Guide: Version Management for Port Updates](../../docs/guide-update-port-versioning.md): Step 4 and later
