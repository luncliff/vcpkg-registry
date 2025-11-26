---
description: 'Search for existing ports by name, URL, or keywords'
agent: 'agent'
tools: ['search/fileSearch', 'search/textSearch', 'search/readFile', 'runCommands/runInTerminal', 'fetch', 'githubRepo']
model: Claude Haiku 4.5 (copilot)
---

# Search Port

Find existing vcpkg ports by name, GitHub URL, or keywords in local registry and upstream microsoft/vcpkg repository.

## Prompt Goals

- Search for ports in local registry (priority)
- Search microsoft/vcpkg upstream repository
- Extract port information from GitHub URLs
- Filter out feature results (show only ports)
- Identify deprecated ports and their alternatives
- Provide dependency information for found ports

## Workflow Expectation

**Default Behavior**: Searches autonomously and generates a comprehensive port listing. Local registry results take priority over upstream.

**Stop Conditions**:
- Port search completed with results summary
- No ports found (report empty results)

**Prompt Forwarding**: 
- If port exists: User decides next action (/install-port or /review-port)
- If port doesn't exist: User may proceed to /create-port

## User Input

Extract port search criteria from natural language input:

**Supported Patterns**:
- Port names: `openssl3`, `zlib-ng`, `tensorflow-lite`
- GitHub URLs: `https://github.com/openssl/openssl` → search for `openssl`
- Keywords: `"ssl library"`, `"tensor flow"`
- Multiple ports: `openssl3, zlib-ng` (search each)

**Examples**:
```
Search for openssl3
Find ports for https://github.com/pytorch/cpuinfo
Check if tensorflow-lite exists
```

## Process

### Phase 1: Parse Search Input

#### Step 1.1: Analyze user input
- Tool: Internal parsing
- Extract: Port names, URLs, keywords

#### Step 1.2: Generate port name candidates from URLs
- Condition: GitHub URL detected
- Action: Extract repository name
- Example: `https://github.com/pytorch/cpuinfo` → `cpuinfo`
- Additional candidates: Add common variations (`pytorch-cpuinfo`)

#### Step 1.3: Prepare search terms
- Normalize: Convert to lowercase
- Create list of candidate port names

### Phase 2: Search Local Registry

#### Step 2.1: Search ports folder
- Tool: `#fileSearch`
- Pattern: `ports/{port-name-candidates}**/vcpkg.json`
- Purpose: Find matching port directories

#### Step 2.2: Run vcpkg search command
- Tool: `#runInTerminal`
- Command: `vcpkg search "{port-name}" --overlay-ports ./ports`
- Purpose: Get port list with descriptions
- Note: May include features in results

#### Step 2.3: Filter feature results
- Action: Parse vcpkg search output
- Remove entries with `[feature]` pattern (e.g., `opencv4[openssl]`)
- Keep only port entries (no square brackets)

#### Step 2.4: Check versions baseline
- Tool: `#textSearch`
- Query: Port name
- File: `versions/baseline.json`
- Purpose: Confirm port is in registry

#### Step 2.5: Read port vcpkg.json (if found)
- Tool: `#readFile`
- File: `ports/{port-name}/vcpkg.json`
- Purpose: Get port metadata (version, description, homepage, dependencies)

#### Step 2.6: Check for deprecation markers
- Tool: `#readFile`
- File: `ports/{port-name}/portfile.cmake`
- Search for: `set(VCPKG_POLICY_EMPTY_PACKAGE enabled)`
- Purpose: Identify deprecated/redirect ports

### Phase 3: Search Upstream vcpkg Repository

#### Step 3.1: Search microsoft/vcpkg ports
- Tool: `#githubRepo`
- Repo: `microsoft/vcpkg`
- Query: `path:ports/{port-name} filename:vcpkg.json`
- Purpose: Check if port exists upstream

#### Step 3.2: Fetch upstream port files (if found)
- Tool: `#fetch`
- URL: `https://raw.githubusercontent.com/microsoft/vcpkg/master/ports/{port-name}/vcpkg.json`
- Purpose: Get upstream port metadata

#### Step 3.3: Fetch upstream version
- Tool: `#fetch`
- URL: `https://raw.githubusercontent.com/microsoft/vcpkg/master/versions/{first-letter}-/{port-name}.json`
- Purpose: Get upstream version history

### Phase 4: Check Project Homepage (if provided URL)

#### Step 4.1: Fetch project repository
- Condition: GitHub URL provided in input
- Tool: `#fetch`
- URL: Provided GitHub repository URL
- Purpose: Get project overview

#### Step 4.2: Fetch latest release
- Tool: `#fetch`
- URL: `{github-url}/releases/latest`
- Purpose: Get latest upstream version

### Phase 5: Get Dependency Information (if port found)

#### Step 5.1: Run vcpkg depend-info
- Condition: Port found in local registry or upstream
- Tool: `#runInTerminal`
- Command: `vcpkg depend-info {port-name} --overlay-ports ./ports`
- Purpose: Get dependency tree

#### Step 5.2: Capture dependency output
- Tool: `#terminalLastCommand`
- Purpose: Include in report

### Phase 6: Generate Report

#### Step 6.1: Compile search results
- Organize by: Local registry, Upstream, Not found
- Mark deprecated ports
- Format as structured markdown

## Reporting

The agent MUST output a single markdown report with deterministic structure (no example filler). Emit all headings in order even if a section is empty (use `None`). Avoid prose beyond concise factual bullets.

### Required Top-Level Headings
1. `# Port Search Report` (title)
2. `## Query Summary`
3. `## Local Registry Results`
4. `## Upstream Results`
5. `## Dependency Information`
6. `## Deprecation & Alternatives`
7. `## Not Found Summary`
8. `## Multi-Port Aggregate` (only for >1 query term)
9. `## Next Steps`

### 1. Query Summary
- Original Input: raw user string
- Parsed Terms: list of normalized port names/keywords
- Timestamp: ISO 8601 UTC (`YYYY-MM-DD HH:MM:SS UTC`)

### 2. Local Registry Results
For each matched port (one bullet each):
- `name` — version (from `vcpkg.json`), status icon (`✅` found, `⚠️` deprecated, `❌` missing)
- Description (first sentence)
- Location: relative path `ports/<name>/`
- Features: list or `None`
If no matches: single line `None`.

### 3. Upstream Results
List ports found in `microsoft/vcpkg` not overridden locally and note version difference:
- Format: `<name>` — upstream version; Compare: local newer|same|older|not present
If none: `None`.

### 4. Dependency Information
For each locally found port (skip if none):
- Port: `<name>`
- Direct Dependencies: comma list with host/tool markers (`vcpkg-cmake (host)`) or `None`
Do not include full tree depth; keep first-level only.

### 5. Deprecation & Alternatives
List deprecated ports (policy empty package detected) with replacement target:
- `<deprecated>` → `<alternative>` (reason: empty package policy)
If none: `None`.

### 6. Not Found Summary
Ports/terms not found locally nor upstream:
- `<term>` — `not found` (if URL provided include repository name analyzed)
If GitHub URL provided and repo exists, append latest tag/release if fetched.
If all found: `None`.

### 7. Multi-Port Aggregate (only when multiple queries)
- Totals: local found, upstream only, deprecated, not found
- Newer Locals: list ports where local version > upstream

### 8. Next Steps
Decision guidance based on results:
- If deprecated ports: suggest installing alternative
- If upstream-only ports: suggest install command `vcpkg install <port>`
- If not found but repo detected: suggest `/create-port <url>`
- If local newer than upstream: note potential contribution
Bulleted actionable lines, else `None`.

### Icons & Conventions
- ✅ present/valid
- ⚠️ deprecated or attention
- ❌ missing/not found
No tables unless >10 results (then optional), prefer bullets.
Keep each bullet ≤120 characters.

### Multi-Port Ordering
Order sections by: found local → upstream-only → deprecated → not found.

### Data Collection Rules
- Do not expand full dependency trees; only direct dependencies from `vcpkg.json`.
- For features: list feature names only (no nested deps) unless explicitly requested.
- GitHub release detection optional; if unavailable write `Latest Release: unknown`.

### Non-Blocking Omissions
- Absence of features is not an issue; show `Features: None`.

This specification replaces previous illustrative examples; generate only live data.
