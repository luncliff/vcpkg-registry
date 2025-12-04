---
description: 'Check for upstream project updates and newer versions'
agent: 'agent'
tools: ['edit/createFile', 'edit/editFiles', 'search/textSearch', 'search/readFile', 'fetch', 'githubRepo', 'todos']
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
- Tool: #tool:search/readFile
- File: `ports/{port-name}/vcpkg.json`
- Purpose: Get current port version

#### Step 1.2: Extract version and homepage
- Parse: `version` field
- Parse: `homepage` field (GitHub URL)
- Note: Version format may be semver (`1.2.3`) or date (`2023-08-02`)

#### Step 1.3: Read portfile.cmake for source info
- Tool: #tool:search/readFile
- File: `ports/{port-name}/portfile.cmake`
- Extract: `REPO` value from `vcpkg_from_github` (e.g., `pytorch/cpuinfo`)
- Extract: `REF` value (git tag or commit)

### Phase 2: Check Upstream Project

#### Step 2.1: Determine project source
- Priority: Use `homepage` from vcpkg.json
- Fallback: Construct GitHub URL from `REPO` in portfile.cmake
- Format: `https://github.com/{owner}/{repo}`

#### Step 2.2: Fetch latest release
- Tool: #tool:fetch
- URL: `{github-url}/releases/latest` (GitHub releases page)
- Alternative: Use GitHub API `https://api.github.com/repos/{owner}/{repo}/releases/latest`
- Purpose: Get latest version tag

#### Step 2.3: Fetch latest tags (if no releases)
- Condition: Project uses tags instead of releases
- Tool: #tool:fetch
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
- Tool: #tool:githubRepo
- Repo: `microsoft/vcpkg`
- Query: `path:ports/{port-name} filename:vcpkg.json`
- Purpose: Check if port exists in upstream vcpkg

#### Step 3.2: Fetch upstream port vcpkg.json
- Condition: Port exists in microsoft/vcpkg
- Tool: #tool:fetch
- URL: `https://raw.githubusercontent.com/microsoft/vcpkg/master/ports/{port-name}/vcpkg.json`
- Purpose: Get upstream port version

#### Step 3.3: Fetch upstream version history
- Tool: #tool:fetch
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
- Tool: #tool:fetch
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

#### Step 6.2: Update work-note.md in workspace root
- Tool: #tool:edit/editFiles (append mode)
- Content: Version check results with timestamp

## Reporting

Replace example reports with a deterministic specification. The agent MUST output a markdown document with required headings below (in order). Emit all headings even if a section is empty (use `None`). Keep bullets concise (≤120 chars). Tables only when comparing ≥2 sources or batch mode.

### Required Top-Level Headings (Single Port)
1. `# Port Upstream Check Report`
2. `## Summary`
3. `## Sources`
4. `## Versions`
5. `## Comparison`
6. `## Release Details`
7. `## Breaking Change Indicators`
8. `## Status`
9. `## Recommendations`
10. `## Next Steps`

### 1. Summary
- Port: `<name>`
- Timestamp: ISO 8601 UTC (`YYYY-MM-DD HH:MM:SS UTC`)
- Outcome: `UP-TO-DATE` | `PATCH AVAILABLE` | `MAJOR UPDATE` | `AHEAD OF UPSTREAM` | `NOT FOUND`
- Local Version: `<value>`
- Upstream Latest: `<value|None>`
- microsoft/vcpkg Version: `<value|None>`

### 2. Sources
- Homepage: URL or `None`
- GitHub Repo: `owner/repo` or `None`
- Release Source Type: `release` | `tag` | `commit-snapshot`

### 3. Versions
Bullet or mini-table of:
- Local: `<version>` (normalized form)
- Upstream Project: `<version>` (raw tag + normalized)
- microsoft/vcpkg: `<version|None>`
- REF Pattern: from portfile (`v${VERSION}` / `${VERSION}` / `<name>-${VERSION}` / commit SHA)

### 4. Comparison
- Local vs Upstream: `equal` | `behind` | `ahead`
- Local vs microsoft/vcpkg: `equal` | `newer` | `older` | `absent`
- Upstream vs microsoft/vcpkg: `equal` | `upstream newer` | `upstream older`
- Version Age (days since upstream release): `<n>` or `unknown`

### 5. Release Details
- Latest Tag: `<tag>`
- Release Date: `<YYYY-MM-DD>` or `unknown`
- Tag Prefix Handling: how normalized (e.g., strip `v`, strip `openssl-`)
- Changelog Files Found: list or `None`

### 6. Breaking Change Indicators
Scan changelog lines (if fetched) for keywords:
- Keywords Found: list (`breaking`, `deprecated`, `removed`, `incompatible`) or `None`
- Potential Risk: `low` | `medium` | `high` (heuristic: major bump or keyword presence)

### 7. Status
- Classification: one line summary (e.g., `Local behind upstream by 2 patch versions`)
- Security Fix Mention: yes/no/unknown (if keywords `CVE`, `security` present)

### 8. Recommendations
Prioritized actionable bullets:
- Upgrade command suggestion (`/upgrade-port <name> <version>`) if behind
- Delay suggestion for major bump (advise review / separate port)
- Contribute upstream (if local ahead of microsoft/vcpkg)
- Re-check later (if no upstream release for long period)
If none: `None`

### 9. Next Steps
Ordered list (max 5) tailored to outcome:
- PATCH AVAILABLE: upgrade → test → add version
- MAJOR UPDATE: review breaking changes → consider separate port → optional upgrade test
- AHEAD OF UPSTREAM VCPKG: consider contribution PR
- UP-TO-DATE: optional periodic recheck
- NOT FOUND: verify homepage or port name

### Batch Mode (Multiple Ports)
Add headings after Summary:
12. `## Batch Summary`
13. `## Ports Requiring Action`
14. `## Up-to-Date Ports`

Batch Summary Table Columns:
- Port | Local | Upstream | Vcpkg | Status (short code: OK / PATCH / MAJOR / AHEAD / MISS)

Ports Requiring Action: detailed bullets (one line each):
- `<port>`: local `<x>` → upstream `<y>` (reason: security|patch|major)

Up-to-Date Ports: list or `None`

### Conventions
- Icons: ✅ current, ⚠️ attention (behind/major/ahead), ❌ missing
- Use tables only for `Versions` and batch summary; otherwise bullets
- Normalize versions before comparison; preserve raw tag in Release Details
- Do not dump full changelog; only list detected keywords

### Normalization Rules
- Strip leading `v` or `<name>-` prefixes from tags
- Accept date formats and treat lexicographically for comparison if both date-based
- Mixed date vs semver: report `incompatible format` under Comparison

### Security Detection Heuristics
- If release notes contain `CVE` or `security` → set Security Fix Mention = yes

### Non-Blocking Conditions
- Local ahead of microsoft/vcpkg but equal to upstream
- Missing microsoft/vcpkg entry (private-only port)

### Blocking / High Priority Conditions
- Security fixes available
- Behind by >0 patch versions (patch classification)
- Major version bump (needs review rather than auto-upgrade)

This specification replaces prior example reports; output only real comparison data.
