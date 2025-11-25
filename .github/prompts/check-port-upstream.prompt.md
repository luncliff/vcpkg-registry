---
description: 'Check for upstream project updates and newer versions'
agent: 'agent'
tools: ['edit/editFiles', 'search/textSearch', 'search/readFile', 'fetch', 'githubRepo']
model: Claude Haiku 4.5 (copilot)
---

# Check Port Upstream

Monitor upstream project for new releases and compare with current port version in local registry and microsoft/vcpkg.

## Prompt Goals

- Read current port version from vcpkg.json
- Fetch latest upstream release from project repository
- Check microsoft/vcpkg for upstream port version
- Compare versions (local, upstream project, microsoft/vcpkg)
- Identify version discrepancies
- Report upgrade opportunities
- Generate actionable update recommendations

## Workflow Expectation

**Default Behavior**: Autonomously reads port files, fetches upstream data, compares versions, and generates version comparison report.

**Stop Conditions**:
- Version check completed with comparison report
- Upgrade recommendations provided (if newer version available)

**Prompt Forwarding**:
- If newer version found: User may proceed to `/upgrade-port` to update the port
- If port is up-to-date: No action needed

## User Input

Extract port name from natural language input:

**Supported Patterns**:
- Port names: `openssl3`, `cpuinfo`, `tensorflow-lite`
- Multiple ports: `openssl3, zlib-ng, cpuinfo` (batch check)
- With context: `check if openssl3 has updates`

**Examples**:
```
Check openssl3 for updates
Is cpuinfo up to date?
Check for newer versions of tensorflow-lite
```

## Process

### Phase 1: Read Current Port Version

#### Step 1.1: Locate port vcpkg.json
- Tool: `#readFile`
- File: `ports/{port-name}/vcpkg.json`
- Purpose: Get current port version

#### Step 1.2: Extract version and homepage
- Parse: `version` field
- Parse: `homepage` field (GitHub URL)
- Note: Version format may be semver (`1.2.3`) or date (`2023-08-02`)

#### Step 1.3: Read portfile.cmake for source info
- Tool: `#readFile`
- File: `ports/{port-name}/portfile.cmake`
- Extract: `REPO` value from `vcpkg_from_github` (e.g., `pytorch/cpuinfo`)
- Extract: `REF` value (git tag or commit)

### Phase 2: Check Upstream Project

#### Step 2.1: Determine project source
- Priority: Use `homepage` from vcpkg.json
- Fallback: Construct GitHub URL from `REPO` in portfile.cmake
- Format: `https://github.com/{owner}/{repo}`

#### Step 2.2: Fetch latest release
- Tool: `#fetch`
- URL: `{github-url}/releases/latest` (GitHub releases page)
- Alternative: Use GitHub API `https://api.github.com/repos/{owner}/{repo}/releases/latest`
- Purpose: Get latest version tag

#### Step 2.3: Fetch latest tags (if no releases)
- Condition: Project uses tags instead of releases
- Tool: `#fetch`
- URL: `{github-url}/tags`
- Purpose: Get latest version tag

#### Step 2.4: Extract upstream version
- Parse: Release tag name (strip leading 'v' if present)
- Example: `v3.0.15` → `3.0.15`
- Example: `openssl-3.0.15` → `3.0.15`

#### Step 2.5: Get release date
- Parse: Release published date
- Purpose: Include in version comparison report

### Phase 3: Check microsoft/vcpkg Upstream

#### Step 3.1: Search microsoft/vcpkg for port
- Tool: `#githubRepo`
- Repo: `microsoft/vcpkg`
- Query: `path:ports/{port-name} filename:vcpkg.json`
- Purpose: Check if port exists in upstream vcpkg

#### Step 3.2: Fetch upstream port vcpkg.json
- Condition: Port exists in microsoft/vcpkg
- Tool: `#fetch`
- URL: `https://raw.githubusercontent.com/microsoft/vcpkg/master/ports/{port-name}/vcpkg.json`
- Purpose: Get upstream port version

#### Step 3.3: Fetch upstream version history
- Tool: `#fetch`
- URL: `https://raw.githubusercontent.com/microsoft/vcpkg/master/versions/{first-letter}-/{port-name}.json`
- Purpose: Get version history and latest version

#### Step 3.4: Extract microsoft/vcpkg version
- Parse: `version` field from fetched vcpkg.json
- Purpose: Compare with local and upstream project versions

### Phase 4: Compare Versions

#### Step 4.1: Normalize version formats
- Strip: Leading 'v' characters
- Strip: Project name prefixes (e.g., `openssl-3.0.15` → `3.0.15`)
- Parse: Semver components (major.minor.patch)
- Parse: Date formats (YYYY-MM-DD)

#### Step 4.2: Perform version comparison
- Compare: Local registry version vs. upstream project version
- Compare: Local registry version vs. microsoft/vcpkg version
- Compare: microsoft/vcpkg version vs. upstream project version

#### Step 4.3: Determine version status
- **Up-to-date**: Local == Upstream project latest
- **Behind upstream**: Local < Upstream project latest
- **Ahead of upstream**: Local > Upstream project latest (unusual)
- **Diverged**: Local != microsoft/vcpkg != Upstream project

#### Step 4.4: Calculate version age
- Compute: Days since latest upstream release
- Purpose: Assess urgency of update

### Phase 5: Check for Breaking Changes

#### Step 5.1: Fetch upstream changelog (optional)
- Tool: `#fetch`
- Files: `CHANGELOG.md`, `CHANGES.md`, `NEWS.md`, `HISTORY.md`
- URL: `https://raw.githubusercontent.com/{owner}/{repo}/master/CHANGELOG.md`
- Purpose: Identify breaking changes between versions

#### Step 5.2: Scan for breaking change indicators
- Search: Keywords like "breaking", "removed", "deprecated", "incompatible"
- Purpose: Warn about potential issues in upgrade

### Phase 6: Generate Version Report

#### Step 6.1: Compile version comparison
- Format: Table comparing local, microsoft/vcpkg, upstream project
- Highlight: Differences and recommendations

#### Step 6.2: Update work-note.md
- Tool: `#editFiles` (append mode)
- Content: Version check results with timestamp

## Reporting

### Port Up-to-Date

```markdown
# Port Upstream Check

**Port**: `cpuinfo`
**Date**: 2025-11-26 14:05:30

## Version Comparison

| Source | Version | Status |
|--------|---------|--------|
| **Local Registry** | 2023-08-02 | ✅ Current |
| **Upstream Project** | 2023-08-02 | ✅ Same |
| **microsoft/vcpkg** | 2023-08-02 | ✅ Same |

## Upstream Project

- **Repository**: https://github.com/pytorch/cpuinfo
- **Latest Release**: 2023-08-02
- **Release Date**: 2023-08-02
- **Release Age**: 480 days ago

## Status

✅ **Port is up-to-date**

Local registry is using the latest upstream version.

## Next Steps

No updates needed at this time.

Check again periodically for new releases.
```

### Port Behind Upstream

```markdown
# Port Upstream Check

**Port**: `openssl3`
**Date**: 2025-11-26 14:10:15

## Version Comparison

| Source | Version | Status |
|--------|---------|--------|
| **Local Registry** | 3.0.13 | ⚠️ **Behind** |
| **Upstream Project** | 3.0.15 | ✅ Latest |
| **microsoft/vcpkg** | 3.0.13 | ⚠️ Behind |

## Upstream Project

- **Repository**: https://github.com/openssl/openssl
- **Latest Release**: openssl-3.0.15
- **Release Date**: 2024-09-03
- **Release Age**: 85 days ago

## Release Notes

https://github.com/openssl/openssl/releases/tag/openssl-3.0.15

### Highlights
- Security fixes for CVE-2024-XXXX
- Performance improvements in TLS 1.3
- Bug fixes for Windows builds

## Status

⚠️ **Update Available**

Upstream project has 2 newer patch versions (3.0.13 → 3.0.15)

## Upgrade Path

### Option 1: Update Local Port
```powershell
/upgrade-port openssl3 3.0.15
```

### Option 2: Wait for microsoft/vcpkg
- microsoft/vcpkg is also behind
- May want to wait for upstream vcpkg update
- Check microsoft/vcpkg issues: https://github.com/microsoft/vcpkg/issues?q=openssl3

## Breaking Changes

⚠️ Review release notes for compatibility:
- https://github.com/openssl/openssl/releases/tag/openssl-3.0.14
- https://github.com/openssl/openssl/releases/tag/openssl-3.0.15

No major breaking changes reported.

## Next Steps

**Recommended**: Update port to 3.0.15 (security fixes)

```powershell
/upgrade-port openssl3 3.0.15
```

After upgrade, test installation:
```powershell
/install-port openssl3
```
```

### Port Ahead of microsoft/vcpkg

```markdown
# Port Upstream Check

**Port**: `tensorflow-lite`
**Date**: 2025-11-26 14:15:45

## Version Comparison

| Source | Version | Status |
|--------|---------|--------|
| **Local Registry** | 2.14.0 | ✅ Latest |
| **Upstream Project** | 2.14.0 | ✅ Same |
| **microsoft/vcpkg** | 2.10.0 | ⚠️ Behind (4 versions) |

## Upstream Project

- **Repository**: https://github.com/tensorflow/tensorflow
- **Latest Release**: v2.14.0
- **Release Date**: 2023-09-18
- **Release Age**: 435 days ago

## Status

✅ **Local Registry is Up-to-Date**

Local registry has the latest upstream version.

**Note**: microsoft/vcpkg is behind by 4 versions (2.10.0 vs. 2.14.0)

## microsoft/vcpkg Status

Local registry provides newer version than upstream vcpkg.

Consider contributing updated port to microsoft/vcpkg:
1. Review contribution guidelines: https://github.com/microsoft/vcpkg/blob/master/CONTRIBUTING.md
2. Create PR with updated port
3. Reference: https://github.com/microsoft/vcpkg/tree/master/ports/tensorflow-lite

## Next Steps

✅ No updates needed

Optionally contribute to microsoft/vcpkg to help community.
```

### Major Version Available

```markdown
# Port Upstream Check

**Port**: `zlib-ng`
**Date**: 2025-11-26 14:20:30

## Version Comparison

| Source | Version | Status |
|--------|---------|--------|
| **Local Registry** | 2.1.7 | ⚠️ **Major Update Available** |
| **Upstream Project** | 3.0.2 | ✅ Latest (major bump) |
| **microsoft/vcpkg** | 2.1.7 | ⚠️ Behind |

## Upstream Project

- **Repository**: https://github.com/zlib-ng/zlib-ng
- **Latest Release**: v3.0.2
- **Release Date**: 2024-10-15
- **Release Age**: 42 days ago

## Major Version Change

⚠️ **Major version bump detected: 2.x → 3.x**

## Breaking Changes

Review release notes carefully:
- https://github.com/zlib-ng/zlib-ng/releases/tag/3.0.0
- https://github.com/zlib-ng/zlib-ng/releases/tag/3.0.1
- https://github.com/zlib-ng/zlib-ng/releases/tag/3.0.2

### Known Changes
- API changes in compression functions
- Performance improvements
- New features: ...

## Upgrade Considerations

**Test Thoroughly Before Upgrading**:
1. Major version may have breaking API changes
2. Dependent ports may need updates
3. Consider creating separate port (`zlib-ng3`) if needed

## Dependency Impact

Check ports depending on `zlib-ng`:
```powershell
vcpkg depend-info zlib-ng --overlay-ports ./ports
```

## Next Steps

### Option 1: Upgrade to 3.0.2 (Breaking)
```powershell
/upgrade-port zlib-ng 3.0.2
```

**Risk**: May break dependent ports

### Option 2: Create New Port (zlib-ng3)
- Keep `zlib-ng` at 2.1.7 for compatibility
- Create `zlib-ng3` for 3.x series
- Allow gradual migration

### Option 3: Wait for microsoft/vcpkg
- Let upstream vcpkg handle major version
- Adopt their approach

**Recommendation**: Wait for microsoft/vcpkg guidance on major version handling
```

### Batch Check Results

```markdown
# Port Upstream Check (Batch)

**Ports**: 5 ports checked
**Date**: 2025-11-26 14:25:10

## Summary

| Port | Local | Upstream | Status |
|------|-------|----------|--------|
| openssl3 | 3.0.13 | 3.0.15 | ⚠️ Update available |
| cpuinfo | 2023-08-02 | 2023-08-02 | ✅ Up-to-date |
| tensorflow-lite | 2.14.0 | 2.14.0 | ✅ Up-to-date |
| zlib-ng | 2.1.7 | 3.0.2 | ⚠️ Major update |
| abseil | 20240116.0 | 20240116.2 | ⚠️ Update available |

## Ports Needing Updates

### 1. openssl3 (3.0.13 → 3.0.15)
- **Urgency**: High (security fixes)
- **Action**: `/upgrade-port openssl3 3.0.15`

### 2. zlib-ng (2.1.7 → 3.0.2)
- **Urgency**: Low (major version, breaking changes)
- **Action**: Review changes, consider separate port

### 3. abseil (20240116.0 → 20240116.2)
- **Urgency**: Medium (patch update)
- **Action**: `/upgrade-port abseil 20240116.2`

## Ports Up-to-Date

- ✅ cpuinfo
- ✅ tensorflow-lite

## Next Steps

Prioritize security updates first:
1. openssl3 (security fixes)
2. abseil (patch update)
3. zlib-ng (review major version changes)
```

## Work Note Entry

### Up-to-Date

```markdown
## 2025-11-26 14:05:30 - /check-port-upstream

✅ Version check completed
- Port: cpuinfo
- Local: 2023-08-02
- Upstream: 2023-08-02
- Status: Up-to-date
```

### Update Available

```markdown
## 2025-11-26 14:10:15 - /check-port-upstream

⚠️ Update available
- Port: openssl3
- Local: 3.0.13
- Upstream: 3.0.15
- Age: 85 days
- Changes: Security fixes
- Recommendation: Update (high priority)
```
