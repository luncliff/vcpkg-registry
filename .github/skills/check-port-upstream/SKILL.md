---
name: check-port-upstream
description: Check for upstream project updates and newer versions. Use when asked to check for updates, compare versions, or see if a port is outdated.
---

# Check Port Upstream

Monitor upstream project for new releases and compare with current port version in local registry and microsoft/vcpkg.

## Goals

- PASS: Clear version comparison with recommendation (update vs. no action needed).
- FAIL: Unable to confirm upstream status; missing homepage or inaccessible repository.

## Capabilities

- Read current port version from vcpkg.json
- Fetch latest upstream release from project repository
- Check microsoft/vcpkg for upstream port version
- Compare versions (local, upstream project, microsoft/vcpkg)
- Identify version discrepancies
- Report upgrade opportunities
- Generate actionable update recommendations

## User Input

**Supported Patterns**:
- Port names: `openssl3`, `cpuinfo`, `tensorflow-lite`
- Multiple ports: `openssl3, zlib-ng, cpuinfo` (batch check)
- With context: `check if openssl3 has updates`

## Process

### Phase 1: Read Current Port Version

1. Read `ports/{port-name}/vcpkg.json` — extract `version`, `homepage`
2. Read `ports/{port-name}/portfile.cmake` — extract `REPO`, `REF`, `SHA512`
3. Determine source info from `homepage` or `REPO` value

### Phase 2: Check Upstream Project

1. Determine project source (homepage or GitHub URL from portfile)
2. Fetch latest release: `{github-url}/releases/latest` or GitHub API
3. Fetch latest tags if no releases
4. Extract upstream version (strip leading 'v' or project name prefix)
5. Get release date

### Phase 3: Check microsoft/vcpkg Upstream

1. Search microsoft/vcpkg for port: `path:ports/{port-name} filename:vcpkg.json`
2. Fetch upstream `vcpkg.json` from `raw.githubusercontent.com`
3. Fetch version history from `versions/{first-letter}-/{port-name}.json`

### Phase 4: Compare Versions

1. Normalize version formats (strip 'v', project name prefixes)
2. Perform comparisons: local vs upstream, local vs microsoft/vcpkg, microsoft/vcpkg vs upstream
3. Determine status: Up-to-date / Behind upstream / Ahead of upstream / Diverged
4. Calculate version age (days since latest upstream release)

### Phase 5: Check for Breaking Changes

1. Fetch upstream changelog (`CHANGELOG.md`, `CHANGES.md`, `NEWS.md`)
2. Scan for keywords: "breaking", "removed", "deprecated", "incompatible", "CVE", "security"

## Reporting

Output a markdown report with these headings (in order). Emit all headings even if empty (use `None`).

1. `# Port Upstream Check Report`
2. `## Summary` — Port, timestamp, outcome (UP-TO-DATE/PATCH AVAILABLE/MAJOR UPDATE/AHEAD OF UPSTREAM/NOT FOUND), versions
3. `## Sources` — Homepage, GitHub repo, release source type
4. `## Versions` — Local, upstream project, microsoft/vcpkg, REF pattern
5. `## Comparison` — Local vs upstream, local vs microsoft/vcpkg, version age
6. `## Release Details` — Latest tag, release date, tag prefix handling, changelog files
7. `## Breaking Change Indicators` — Keywords found, potential risk level
8. `## Status` — Classification summary, security fix mention
9. `## Recommendations` — Upgrade commands, delay suggestions, contribution opportunities
10. `## Next Steps` — Ordered list tailored to outcome

### Batch Mode (Multiple Ports)
Add `## Batch Summary` table and `## Ports Requiring Action` / `## Up-to-Date Ports` sections.

### Conventions
- Icons: ✅ current, ⚠️ attention (behind/major/ahead), ❌ missing
- Normalize versions before comparison; preserve raw tag in Release Details
- Security detection: if release notes contain `CVE` or `security` → flag

## Next Steps Guidance

- PATCH AVAILABLE: suggest `update-port` skill
- MAJOR UPDATE: review breaking changes → consider separate port
- AHEAD OF UPSTREAM VCPKG: consider contribution PR
- UP-TO-DATE: periodic recheck
