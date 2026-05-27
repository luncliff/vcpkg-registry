---
name: search-port
description: Search for existing vcpkg ports by name, GitHub URL, or keywords in the local registry and upstream microsoft/vcpkg repository. Use when asked to find, search, or check if a port exists.
---

# Search Port

Find existing vcpkg ports by name, GitHub URL, or keywords in the local registry and upstream microsoft/vcpkg repository.

## Goals

- PASS: Clearly identified whether the port exists locally/upstream and recommended next step.
- FAIL: Could not determine port status; search criteria unclear or no results found.

## Capabilities

- Search for ports in local registry (priority)
- Search microsoft/vcpkg upstream repository
- Extract port information from GitHub URLs
- Filter out feature results (show only ports)
- Identify deprecated ports and their alternatives
- Provide dependency information for found ports

## User Input

Extract port search criteria from natural language input:

**Supported Patterns**:
- Port names: `openssl3`, `zlib-ng`, `tensorflow-lite`
- GitHub URLs: `https://github.com/openssl/openssl` → search for `openssl`
- Keywords: `"open"`, `"-ng"`, `"tensorflow"`
- Multiple ports: `openssl3, zlib-ng` (search each)

## Process

### Phase 1: Parse Search Input

1. Analyze user input — extract port names, URLs, keywords
2. Generate port name candidates from URLs (e.g., `https://github.com/pytorch/cpuinfo` → `cpuinfo`)
3. Normalize to lowercase and create list of candidate port names

### Phase 2: Search Local Registry

1. Search `ports/{port-name-candidates}**/vcpkg.json` for matching port directories
2. Run `vcpkg search "{port-name}" --overlay-ports ./ports` to get port list with descriptions
3. Filter feature results — remove entries with `[feature]` pattern, keep only port entries
4. Check `versions/baseline.json` for port presence
5. Read `ports/{port-name}/vcpkg.json` for metadata (version, description, homepage, dependencies)
6. Check `ports/{port-name}/portfile.cmake` for `set(VCPKG_POLICY_EMPTY_PACKAGE enabled)` to identify deprecated ports

### Phase 3: Search Upstream vcpkg Repository

1. Search `microsoft/vcpkg` for `path:ports/{port-name} filename:vcpkg.json`
2. Fetch `https://raw.githubusercontent.com/microsoft/vcpkg/master/ports/{port-name}/vcpkg.json`
3. Fetch `https://raw.githubusercontent.com/microsoft/vcpkg/master/versions/{first-letter}-/{port-name}.json`

### Phase 4: Check Project Homepage (if URL provided)

1. Fetch the provided GitHub repository URL for project overview
2. Fetch `{github-url}/releases/latest` for latest upstream version

### Phase 5: Get Dependency Information (if port found)

1. Run `vcpkg depend-info {port-name} --overlay-ports ./ports`

### Phase 6: Generate Report

Compile results organized by: Local registry, Upstream, Not found.

## Reporting

Output a single markdown report with these required headings (in order). Emit all headings even if empty (use `None`).

1. `# Port Search Report`
2. `## Query Summary` — Original input, parsed terms, timestamp (ISO 8601 UTC)
3. `## Local Registry Results` — Each matched port with version, status (✅/⚠️/❌), description, location, features
4. `## Upstream Results` — Ports found in microsoft/vcpkg not overridden locally, with version comparison
5. `## Dependency Information` — Direct dependencies for locally found ports
6. `## Deprecation & Alternatives` — Deprecated ports with replacements
7. `## Not Found Summary` — Terms not found locally nor upstream
8. `## Multi-Port Aggregate` — (only for >1 query term) Totals and newer locals
9. `## Next Steps` — Decision guidance based on results

### Icons & Conventions
- ✅ present/valid, ⚠️ deprecated or attention, ❌ missing/not found
- Keep each bullet ≤120 characters
- Order sections by: found local → upstream-only → deprecated → not found

## Next Steps Guidance

- If port exists locally: suggest `install-port` or `review-port` skill
- If port doesn't exist: suggest `create-port` skill
- If deprecated: suggest installing alternative
- If upstream-only: suggest `vcpkg install <port>`

## References

- [docs/guide-create-port.md](../../docs/guide-create-port.md)
- [docs/troubleshooting.md](../../docs/troubleshooting.md)
