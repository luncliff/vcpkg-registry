# Guide: Update Port Patches with Editable Source

This guide describes how to refresh existing patch files for a port when upstream changes and old patches no longer apply cleanly.

## Goal

- Rebuild patch files against the current upstream version used by the port.
- Keep patch intent and order stable.
- Ensure all `*.patch` files in the port can be applied by vcpkg.

> **Scope**: This workflow targets **patch applicability only**. Build/configure/install failures after patch application are handled in separate workflows.

## Workflow Summary (10 Steps)

The workflow uses two iteration loops:

- **Patch-level loop** (Steps 3–9): Process one patch file at a time.
- **Diff-level loop** (Steps 5–6): Within a patch, reconcile one hunk/file at a time.

| Step | Action |
|------|--------|
| 1 | Session setup: baseline commit + `patch-guess-note.md` |
| 2 | Patch inventory + order lock |
| 3 | Patch-level attempt (`git apply --reject`) |
| 4 | Fail-fast reset (if needed) |
| 5 | Diff-level decomposition |
| 6 | Diff-level iteration loop |
| 7 | Patch finalize (commit + export) |
| 8 | Patch-level verification |
| 9 | Next patch repeat (loop to Step 3) |
| 10 | Final workflow gate |

## Prerequisites

- Use explicit overlay options (`--overlay-ports`, `--overlay-triplets`) per registry policy.
- Use an editable install once to materialize source under `buildtrees/<port>/src/...`.
- Use PowerShell location stack on Windows (`Push-Location` / `Pop-Location`).
- Treat `PATCHES` order in `portfile.cmake` as canonical during patch refresh.

## Detailed Steps

This guide uses placeholders `<port>`, `<SOURCE_PATH>`, and `<patch-file>`, with tensorflow-lite examples for reference.

### Step 1: Session Setup

Create a baseline commit in editable source and initialize the session note file.

```powershell
# Example: tensorflow-lite
$SourcePath = "C:/vcpkg/buildtrees/tensorflow-lite/src/2.21.0-rc0-7148b9c857"
Push-Location "$SourcePath"
    if (-not (Test-Path ".git")) {
        git init *> $null
    }
    if (-not (git rev-parse --quiet --verify HEAD 2>$null)) {
        git add . *> $null
        git commit -m "baseline without port patches" *> $null
    }
Pop-Location

# Create session note at workspace root
"" | Out-File -FilePath "C:/vcpkg/vcpkg-registry/patch-guess-note.md"
```

The `patch-guess-note.md` file records diff decisions during the session (e.g., hunks absorbed by upstream, guessed context matches). This file is a session artifact at workspace root—NOT committed to the port folder.

### Step 2: Patch Inventory + Order Lock

Lock the canonical patch order from `portfile.cmake`.

```powershell
# List patches in PATCHES order
Get-Content ports/<port>/portfile.cmake | Select-String "\.patch"
```

Example output for tensorflow-lite:
```
fix-cmake-vcpkg.patch
fix-cmake-c-api.patch
fix-headers.patch
```

This order is preserved throughout the workflow. Never reorder patches.

### Step 3: Patch-Level Attempt

Try applying the current patch with `--reject` to isolate failures.

```powershell
Push-Location "$SourcePath"
    git apply --reject --whitespace=nowarn `
        "C:/vcpkg/vcpkg-registry/ports/<port>/<patch-file>.patch"
Pop-Location
```

**Outcomes**:
- **Clean apply**: No `.rej` files created → skip to Step 7.
- **Partial apply**: Some hunks applied, `.rej` files created for failures → continue to Step 4.
- **Total failure**: All hunks rejected → continue to Step 4.

### Step 4: Fail-Fast Reset

If the patch attempt left dirty state or `.rej` files, reset to retry cleanly.

```powershell
Push-Location "$SourcePath"
    git checkout -- .
    Get-ChildItem -Recurse -Filter "*.rej" | Remove-Item
Pop-Location
```

⚠️ **Warning**: Reset discards all uncommitted changes. Make sure Step 7 commit was done for previous patches.

### Step 5: Diff-Level Decomposition

Break the patch into individual hunks/files for incremental reconciliation.

1. Open the original patch file and identify discrete changes.
2. List each change intent (1 line per hunk group).
3. Mark hunks as:
   - `must-apply`: Change still needed.
   - `absorbed-upstream`: Upstream already includes equivalent change.
   - `context-drift`: Logic still needed but line numbers/context shifted.

Document decisions in `patch-guess-note.md`:

```markdown
## fix-cmake-vcpkg.patch

- Hunk 1: vcpkg toolchain path fix → must-apply (line 42→47)
- Hunk 2: remove hardcoded /usr/local → absorbed-upstream
- Hunk 3: add VCPKG_TARGET_TRIPLET → must-apply (context-drift)
```

### Step 6: Diff-Level Iteration Loop

For each `must-apply` or `context-drift` item:

1. **Locate** the target file and region in editable source.
2. **Apply** the intended change manually (edit the file directly).
3. **Stage** the change: `git add <file>` or `git add -p` for partial staging.
4. **Verify** with `git diff --cached`.
5. **Repeat** until all items for this patch are staged.

```powershell
Push-Location "$SourcePath"
    # After manual edits:
    git add CMakeLists.txt
    git diff --cached  # Review staged changes
Pop-Location
```

### Step 7: Patch Finalize (Commit + Export)

Commit the staged changes and export back to the registry patch file.

```powershell
Push-Location "$SourcePath"
    git commit -m "<patch-file> refresh for <version>"
    git diff HEAD~1 HEAD > "C:/vcpkg/vcpkg-registry/ports/<port>/<patch-file>.patch"
Pop-Location
```

The commit history builds a stack: one commit per patch in PATCHES order.

### Step 8: Patch-Level Verification

Verify the exported patch applies cleanly from a fresh state.

```powershell
Push-Location "$SourcePath"
    git stash  # Temporarily stash if needed
    git checkout HEAD~1  # Go back one commit
    git apply --check "C:/vcpkg/vcpkg-registry/ports/<port>/<patch-file>.patch"
    git checkout -  # Return to latest
    git stash pop 2>$null  # Restore stash if any
Pop-Location
```

If `--check` fails, return to Step 4 and re-examine the diff.

### Step 9: Next Patch Repeat

Return to **Step 3** for the next patch in PATCHES order.

Continue until all patches are processed. The commit history should now have N commits (one per patch) stacked on the baseline.

### Step 10: Final Workflow Gate

Re-enable patches and validate with a fresh editable install.

```powershell
# 1. Re-enable PATCHES in portfile.cmake (uncomment if commented)
# 2. Run fresh editable install
vcpkg install --overlay-ports=ports `
    --x-buildtrees-root buildtrees `
    --x-packages-root packages `
    --x-install-root installed `
    --editable <port>
```

**Success criteria**:
- vcpkg output shows `-- Applying patch <name>.patch` for each patch.
- No patch application errors.

**If patches fail to apply**:
- Note the failing patch and error message.
- The editable source from `-- Using source at ...` becomes the new iteration baseline.
- Return to Step 1 using this new source path.

**If build/configure fails after patch application**:
- Record the failure log path.
- Stop this workflow—patch refresh is complete.
- Continue in troubleshooting or build-fix workflows.

## Session Artifact: patch-guess-note.md

The `patch-guess-note.md` file at workspace root documents decisions made during diff reconciliation:

- Which hunks were absorbed by upstream.
- Which hunks required context adjustment.
- Any guesses about line number drift.

Use this content for PR descriptions or commit notes. Delete after the PR is merged.

## Patch Naming Convention

Follow these patterns for new or renamed patches:

| Pattern | Example | Use Case |
|---------|---------|----------|
| `fix-<buildsystem>.patch` | `fix-cmake.patch` | General build system fix |
| `fix-<buildsystem>-<feature>.patch` | `fix-cmake-cuda.patch` | Feature-specific fix |
| `fix-<component>.patch` | `fix-headers.patch` | Non-build-system fix |

Multi-file patches are allowed when changes are logically related.

## Practical Notes

- **Suppress git noise**: Use `*> $null` when initializing or bulk-adding.
- **Single concern per patch**: Do not mix unrelated fixes.
- **Prefer git diff export**: Regenerate patches from commits rather than hand-editing patch text.
- **Clean up `.rej` files**: Always remove after reconciliation to avoid confusion.
- **Fragile patches**: Document in `portfile.cmake` comments if a patch is known to break often.
- **Feature-conditional patches**: Not supported; all patches must apply unconditionally.
