---
name: update-port
description: Update an existing port to a newer upstream version with SHA512 calculation and testing. Use when asked to update, upgrade, or bump a port version.
---

# Update Port

Update an existing port to a newer upstream version by modifying vcpkg.json and portfile.cmake, calculating new SHA512, and testing with --editable flag.

## Goals

- PASS: Port updated and tested successfully; ready for review and version baseline update.
- FAIL: Update blocked by unresolved errors; clear classification and suggested fixes provided.

## Capabilities

- Read current port files (vcpkg.json, portfile.cmake)
- Update version in vcpkg.json
- Update REF and SHA512 in portfile.cmake
- Calculate new SHA512 for source archive
- Test installation with `--editable` flag
- Generate upgrade report with validation results

## User Input

**Supported Patterns**:
- Port name with version: `openssl3 3.0.15`, `update cpuinfo to 2024-01-15`
- Without version: `update tensorflow-lite` (fetch latest from upstream)
- With URL: `update openssl3 from https://github.com/openssl/openssl/releases/tag/openssl-3.0.15`

## Process

### Phase 1: Analyze Current Port

1. Read `ports/{port-name}/vcpkg.json` — extract current `version`, `homepage`
2. Read `ports/{port-name}/portfile.cmake` — extract `REPO`, `REF`, `SHA512`, `HEAD_REF`
3. Determine target version:
   - If specified: use directly
   - If not: fetch latest release from upstream (use `check-port-upstream` logic)

### Phase 2: Gather New Version Information

1. Normalize target version (strip 'v', project name prefix)
2. Construct source URL: `https://github.com/{owner}/{repo}/archive/refs/tags/{tag}.tar.gz`
3. Determine REF value pattern:
   - `v${VERSION}` for projects using `v1.2.3` tags
   - `openssl-${VERSION}` for OpenSSL-style
   - `${VERSION}` for simple tags

### Phase 3: Calculate New SHA512

1. Download source archive:
   - PowerShell: `curl -L -o "temp-${Version}.tar.gz" $Url`
   - Bash: `curl -L -o "temp-${version}.tar.gz" "$url"`
2. Calculate SHA512:
   - PowerShell: `(Get-FileHash -Algorithm SHA512 "temp-${Version}.tar.gz").Hash.ToLower()`
   - Bash: `sha512sum "temp-${version}.tar.gz" | awk '{print $1}'`
3. Verify: exactly 128 hex characters, lowercase
4. Clean up downloaded archive
5. Fallback: use `0` as placeholder if download fails (vcpkg reports correct SHA512 on first attempt)

### Phase 4: Update Port Files

1. Update `vcpkg.json`: change `"version"` field to new version
2. Update `portfile.cmake`:
   - Update `REF` (if hardcoded; skip if using `${VERSION}` variable)
   - Update `SHA512` to new value
3. Review other version references in comments or OPTIONS

### Phase 5: Test Upgrade with --editable

1. Run vcpkg install with --editable:
   ```powershell
   vcpkg install --editable `
     --overlay-ports ./ports `
     --x-buildtrees-root buildtrees `
     --x-packages-root packages `
     --x-install-root installed `
     {port-name}
   ```
2. Analyze results:
   - Success: exit code 0, "successfully installed" message
   - SHA512 mismatch: extract correct SHA512 from error, update portfile, retry
   - Build errors: analyze logs, suggest patches

### Phase 6: Validate File Changes

1. Re-read updated `vcpkg.json` — verify version correct
2. Re-read updated `portfile.cmake` — verify SHA512 and REF correct
3. Run format-manifest:
   ```powershell
   ./scripts/registry-format.ps1 -VcpkgRoot "$env:VCPKG_ROOT" -RegistryRoot "$(Get-Location)"
   ```

## Reporting

Output a markdown report with these headings (in order). Emit all headings even if empty (use `None`).

1. `# Port Upgrade Report`
2. `## Summary` — Port, old/new version, timestamp, outcome (SUCCESS/FAILURE/SHA512 CORRECTED), mode
3. `## Version Changes` — vcpkg.json change, REF strategy, major/minor classification
4. `## Source & SHA512` — Source URL, new SHA512, acquisition method, placeholder/correction
5. `## File Modifications` — Changed lines in vcpkg.json and portfile.cmake
6. `## Test Installation` — Command, result, duration, artifacts, log path (if failed)
7. `## Validation` — Version field, SHA512, REF pattern, editable test, baseline update needed
8. `## Issues & Warnings` — Critical issues and warnings with fix actions
9. `## Next Steps` — Based on outcome: commit → registry-add-version → commit versions

### Conventions
- Icons: ✅ valid, ⚠️ warning, ❌ error
- Keep bullets ≤120 chars
- Show at most first 16 chars of old/new SHA512 when contrasting

## Next Steps Guidance

- SUCCESS: recommend commit changes → run `./scripts/registry-add-version.ps1` → recommend commit versions → open PR
- SHA512 CORRECTED: retest then commit
- FAILURE: analyze logs, consider patches, optional rollback
