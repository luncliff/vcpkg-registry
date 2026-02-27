---
description: 'Refresh port patch files when upstream changes break patch application'
agent: 'agent'
tools: [vscode, execute, read, agent, edit, search, web, todo]
model: Claude Sonnet 4.5 (copilot)
---

# Update Port Patches

Refresh existing patch files for a port when upstream version changes cause patches to fail. Uses editable source with git-based tracking to rebuild patches incrementally.

## Prompt Goals

- PASS: All patches in `PATCHES` list apply cleanly in editable install.
- FAIL: One or more patches cannot be reconciled; clear indication of blocking hunk.

**Scope**: Patch applicability only. Build/configure/install failures after patches apply are out of scope.

**Session Artifact**: Creates `patch-guess-note.md` at workspace root documenting diff decisions.

## Workflow Expectation

**Default Behavior**: Autonomously processes patches in PATCHES order, reconciles rejected hunks, exports refreshed patches, and validates with editable install.

**Stop Conditions**:
- All patches apply cleanly (PASS)
- A patch cannot be reconciled after retry (FAIL)

**Prompt Forwarding**:
- If PASS: User should run `/install-port` to verify build, then `/update-version-baseline`
- If FAIL: User must manually resolve blocking hunk or reconsider patch necessity

## User Input

Extract port name from natural language input:

**Supported Patterns**:
- Port name: `update patches for tensorflow-lite`
- Port name with context: `refresh openssl3 patches for 3.0.15`
- Direct: `tensorflow-lite patches`

**Examples**:
```
Update patches for tensorflow-lite
Refresh openssl3 patches
Fix failing patches in onnxruntime
```

## Process

### Phase 1: Session Setup

#### Step 1.1: Identify port and patches
- Tool: #tool:search/fileSearch
- Pattern: `ports/{port-name}/*.patch`
- Extract: List of patch files

#### Step 1.2: Read portfile.cmake for PATCHES order
- Tool: #tool:read/readFile
- File: `ports/{port-name}/portfile.cmake`
- Extract: Canonical patch order from `PATCHES` block

#### Step 1.3: Run initial editable install (patches commented out)
- Condition: PATCHES block should be commented to get clean source
- Tool: #tool:execute/runInTerminal
- Command:
  ```powershell
  vcpkg install --overlay-ports=ports `
    --x-buildtrees-root buildtrees `
    --x-packages-root packages `
    --x-install-root installed `
    --editable {port-name}
  ```
- Extract: `SOURCE_PATH` from `-- Using source at ...` output

#### Step 1.4: Initialize git baseline in editable source
- Tool: #tool:execute/runInTerminal
- Command:
  ```powershell
  Push-Location "{SOURCE_PATH}"
      if (-not (Test-Path ".git")) { git init *> $null }
      if (-not (git rev-parse --quiet --verify HEAD 2>$null)) {
          git add . *> $null
          git commit -m "baseline without port patches" *> $null
      }
  Pop-Location
  ```

#### Step 1.5: Create session note file
- Tool: #tool:edit/createFile
- File: `patch-guess-note.md` (workspace root)
- Content: Header with port name and date

### Phase 2: Patch-Level Loop

For each patch in PATCHES order, execute Steps 2.1–2.7.

#### Step 2.1: Attempt patch application
- Tool: #tool:execute/runInTerminal
- Command:
  ```powershell
  Push-Location "{SOURCE_PATH}"
      git apply --reject --whitespace=nowarn "{registry-path}/ports/{port-name}/{patch-file}.patch"
  Pop-Location
  ```
- Analyze: Check for `.rej` files or clean apply

#### Step 2.2: Handle clean apply
- Condition: No `.rej` files, exit code 0
- Action: Stage all changes, commit, export patch, skip to Step 2.7

#### Step 2.3: Fail-fast reset (if rejected hunks)
- Condition: `.rej` files exist
- Tool: #tool:execute/runInTerminal
- Command:
  ```powershell
  Push-Location "{SOURCE_PATH}"
      git checkout -- .
      Get-ChildItem -Recurse -Filter "*.rej" | Remove-Item
  Pop-Location
  ```
- ⚠️ Warning emitted: "Patch {name} has rejected hunks, resetting for manual reconciliation"

#### Step 2.4: Diff-level decomposition
- Tool: #tool:read/readFile
- File: Original patch file
- Action: List hunks with intent classification:
  - `must-apply`: Change still required
  - `absorbed-upstream`: Upstream includes equivalent change
  - `context-drift`: Logic needed but context shifted
- Update: `patch-guess-note.md` with decisions

#### Step 2.5: Diff-level iteration
For each `must-apply` or `context-drift` hunk:
- Locate target file and region in editable source
- Apply change manually (edit file)
- Stage change: `git add {file}`
- Verify: `git diff --cached`
- Repeat until all hunks staged

#### Step 2.6: Finalize patch
- Tool: #tool:execute/runInTerminal
- Commands:
  ```powershell
  Push-Location "{SOURCE_PATH}"
      git commit -m "{patch-file} refresh"
      git diff HEAD~1 HEAD > "{registry-path}/ports/{port-name}/{patch-file}.patch"
  Pop-Location
  ```

#### Step 2.7: Continue to next patch
- Repeat Phase 2 for next patch in PATCHES order
- Commit stack grows: 1 commit per patch

### Phase 3: Final Validation

#### Step 3.1: Re-enable PATCHES in portfile.cmake
- Tool: #tool:edit/editFiles
- File: `ports/{port-name}/portfile.cmake`
- Action: Uncomment PATCHES block if commented

#### Step 3.2: Run validation editable install
- Tool: #tool:execute/runInTerminal
- Command:
  ```powershell
  vcpkg install --overlay-ports ./ports `
    --x-buildtrees-root buildtrees `
    --x-packages-root packages `
    --x-install-root installed `
    --editable {port-name}
  ```

#### Step 3.3: Analyze validation result
- Success: Output shows `-- Applying patch {name}.patch` for all patches, no errors
- Failure: Patch apply error → extract failing patch, return to Phase 2 with new SOURCE_PATH

#### Step 3.4: Classify final outcome
- PASS: All patches apply
- FAIL: Unrecoverable patch failure after retry

## Reporting

Generate a deterministic markdown report with exact headings below.

### Required Top-Level Headings
1. `# Patch Refresh Report`
2. `## Summary`
3. `## Patch Inventory`
4. `## Reconciliation Details`
5. `## Validation`
6. `## Session Artifact`
7. `## Issues & Warnings`
8. `## Next Steps`

### 1. Summary
- Port: `<name>`
- Version: `<version>` (from vcpkg.json)
- Timestamp: ISO 8601 UTC
- Outcome: `PASS` | `FAIL`
- Patches Processed: `N/N`

### 2. Patch Inventory
Table format:
| # | Patch File | Status | Hunks |
|---|------------|--------|-------|
| 1 | fix-cmake.patch | ✅ Clean | 3/3 |
| 2 | fix-headers.patch | ⚠️ Reconciled | 2/3 |
| 3 | fix-cuda.patch | ❌ Failed | 0/2 |

### 3. Reconciliation Details
Per-patch subsection (only for reconciled/failed patches):
```
### fix-headers.patch
- Hunk 1: `must-apply` → line 42→47 (context drift)
- Hunk 2: `absorbed-upstream` → skipped
- Hunk 3: `must-apply` → applied as-is
```

### 4. Validation
- Editable Install Command: (single line)
- Patches Applied: list with ✅/❌ per patch
- Build Stage Reached: yes/no
- Build Result: (out of scope) / success / failure

### 5. Session Artifact
- File: `patch-guess-note.md`
- Location: workspace root
- Action: Include in PR description, delete after merge

### 6. Issues & Warnings
- Warnings: Non-blocking (context drift, absorbed hunks)
- Critical: Blocking issues (unreconcilable hunk, missing file)

### 7. Next Steps
Branch by outcome:
- PASS: Commit patch changes → run `/install-port` → run `/update-version-baseline`
- FAIL: Review blocking hunk → decide: fix manually | remove patch | upstream PR

## Conventions

- Icons: ✅ success, ⚠️ warning/reconciled, ❌ failure
- Keep bullets ≤120 chars
- Reference log paths, don't dump full logs
- `patch-guess-note.md` is mandatory every session

## References

- [Guide: Update Port Patches](../../docs/guide-update-port-patches.md)
- [Guide: Updating an Existing Port](../../docs/guide-update-port.md)
- [Troubleshooting](../../docs/troubleshooting.md)
