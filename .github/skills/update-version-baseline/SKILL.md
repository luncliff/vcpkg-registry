---
name: update-version-baseline
description: Update registry baseline and version JSON files for ports using the helper script. Use when asked to update the version baseline, register versions, or add version entries.
---

# Update Version Baseline

Register one or more ports into the registry `versions/` tracking (modifies `versions/baseline.json` and `versions/<letter>-/<port>.json` files) using the helper script `./scripts/registry-add-version.ps1`. Falls back to inferring ports from recent context when explicit names are not provided.

## Goals

- PASS: Version baseline updated consistently for target ports; `versions/` JSON files validated.
- FAIL: Baseline update incomplete or invalid; errors reported with actionable fixes.

## Capabilities

- Accept port names (single or multiple) or infer from session context
- Validate ports exist in `ports/` folder
- Run `registry-add-version.ps1` for each port
- Capture and summarize script output
- Suggest commit commands for baseline/version changes (only commit when explicitly requested)

## User Input

**Supported Patterns**:
- Single port name: `openssl3`
- Multiple ports: `onnx onnx-optimizer onnxruntime`
- Natural language: `update baseline for ruy and cpuinfo`
- Empty input: infer from session chat or latest 3 git commit logs

## Process

### Phase 1: Determine Target Ports

1. Parse explicit input — use names directly if provided
2. Infer from context or git logs if no names given:
   - Look for filenames like `ports/<name>/...`
   - Look for mentions like `upgrade <name>`
3. Validate existence: check `ports/{name}/vcpkg.json` exists
4. Format the port files:
   ```powershell
   ./scripts/registry-format.ps1 -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
   ```

### Phase 2: Execute Registry Add-Version

1. If files in ports folder changed, recommend committing:
   ```powershell
   # Suggest to user:
   git add ./ports/port-name/
   git commit -m "[port-name] commit formatting changes"
   ```
2. Run script per port:
   ```powershell
   $RegistryRoot = (Get-Location).Path
   $VcpkgRoot = $env:VCPKG_ROOT
   foreach ($p in $Ports) {
     ./scripts/registry-add-version.ps1 -PortName $p -VcpkgRoot $VcpkgRoot -RegistryRoot $RegistryRoot
   }
   ```
3. Capture output and check for errors

### Phase 3: Results & Recommendations

1. Summarize changes — list updated files under `versions/`
2. Recommend commit for versions folder changes (only if user requests):
   ```powershell
   # Suggest to user:
   git add ./versions
   git commit -m "[<port-name>] update baseline"
   ```

## Error Handling

- Missing `vcpkg` or CLI tool error: suggest running `check-environment` skill
- Port unknown: suggest checking name or creating the port
- Script failure: show terminal output and diagnose messages

## Reporting

Output a markdown report with these headings (in order). Emit all headings even if empty (use `None`).

1. `# Update Version Baseline Report`
2. `## Summary` — Timestamp, ports requested, ports processed, outcome (READY/WARN/ERROR)
3. `## Ports` — Valid (found in `ports/`), Invalid (missing or unresolved)
4. `## Changes` — Updated files: `versions/<letter>-/<port>.json`, `versions/baseline.json`
5. `## Errors` — List of failures with brief context
6. `## Recommendations` — Actionable suggestions
7. `## Next Steps` — Open PR, link to upstream release notes
