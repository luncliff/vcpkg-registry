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

#### Step 6.2: Update work-note.md
- Tool: `#editFiles` (append mode)
- Content: Port search results with timestamp

## Reporting

### Port Found in Local Registry

```markdown
# Port Search Report

**Search Query**: openssl3
**Date**: 2025-11-26 10:40:23

## Local Registry

✅ **Found**: `openssl3`

### Port Details

- **Version**: 3.0.15
- **Description**: OpenSSL is an open-source implementation of the SSL and TLS protocols
- **Homepage**: https://www.openssl.org
- **License**: Apache-2.0
- **Location**: `ports/openssl3/`

### Dependencies

```
openssl3:x64-windows
  - vcpkg-cmake:host
  - vcpkg-cmake-config:host
```

### Features

- `tools`: Build command-line tools

## Upstream Comparison

⚠️ **microsoft/vcpkg Version**: 3.0.13 (older than local)
- Local registry has newer version

## Status

✅ Port ready for use in local registry
```

### Port Found Only Upstream

```markdown
# Port Search Report

**Search Query**: tensorflow
**Date**: 2025-11-26 10:42:15

## Local Registry

❌ **Not Found**: `tensorflow`

## Upstream (microsoft/vcpkg)

✅ **Found**: `tensorflow-cc`

### Port Details

- **Version**: 2.10.0
- **Description**: TensorFlow C++ API
- **Homepage**: https://www.tensorflow.org
- **Location**: https://github.com/microsoft/vcpkg/tree/master/ports/tensorflow-cc

## Suggestions

Consider creating local port or using upstream port.

To use upstream port:
```powershell
vcpkg install tensorflow-cc
```

To create local port:
```powershell
/create-port https://github.com/tensorflow/tensorflow
```
```

### Deprecated Port Found

```markdown
# Port Search Report

**Search Query**: openssl1
**Date**: 2025-11-26 10:44:30

## Local Registry

⚠️ **Found (Deprecated)**: `openssl1`

### Deprecation Notice

This port is deprecated and redirects to `openssl3`.

**Reason**: `set(VCPKG_POLICY_EMPTY_PACKAGE enabled)` detected in portfile.cmake

### Migration Path

Use `openssl3` instead:
```powershell
vcpkg install --overlay-ports ./ports openssl3
```

## Recommended Alternative

✅ **openssl3** (version 3.0.15)
- **Description**: OpenSSL is an open-source implementation of the SSL and TLS protocols
- **Location**: `ports/openssl3/`
```

### Multiple Ports Found

```markdown
# Port Search Report

**Search Query**: ssl
**Date**: 2025-11-26 10:46:12

## Local Registry

Found 3 matching ports:

### 1. openssl3
- **Version**: 3.0.15
- **Description**: OpenSSL is an open-source implementation of the SSL and TLS protocols
- **Location**: `ports/openssl3/`

### 2. apple-nio-ssl
- **Version**: 1.0.0
- **Description**: Swift NIO SSL/TLS support
- **Location**: `ports/apple-nio-ssl/`

### 3. openssl1 (⚠️ Deprecated)
- **Redirects to**: openssl3
- **Location**: `ports/openssl1/`

## Upstream

Additional matches in microsoft/vcpkg:
- `boringssl` (Google's fork of OpenSSL)
- `libressl` (OpenBSD's SSL/TLS library)
```

### Port Not Found

```markdown
# Port Search Report

**Search Query**: nonexistent-lib
**Date**: 2025-11-26 10:48:45

## Local Registry

❌ **Not Found**: `nonexistent-lib`

## Upstream (microsoft/vcpkg)

❌ **Not Found**: `nonexistent-lib`

## Project Homepage (if URL provided)

✅ **GitHub**: https://github.com/example/nonexistent-lib
- Latest Release: v1.2.3
- Description: Example library for demonstration

## Next Steps

Port does not exist. Consider creating a new port:
```powershell
/create-port https://github.com/example/nonexistent-lib
```
```

## Work Note Entry

```markdown
## 2025-11-26 10:40:23 - /search-port

✅ Port search completed
- Query: openssl3
- Found in local registry: Yes (v3.0.15)
- Found in upstream: Yes (v3.0.13)
- Local has newer version
```

### For Not Found

```markdown
## 2025-11-26 10:48:45 - /search-port

✅ Port search completed
- Query: nonexistent-lib
- Found in local registry: No
- Found in upstream: No
- Project exists on GitHub: Yes (v1.2.3)
- Suggested action: Create new port
```
