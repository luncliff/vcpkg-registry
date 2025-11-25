# GitHub Copilot Chat Tools Reference

This document provides a comprehensive reference for built-in tools available in Visual Studio Code when using GitHub Copilot Chat. These tools extend chat capabilities with specialized functionality for accomplishing specific tasks.

## Table of Contents

- [Overview](#overview)
- [How to Use Tools](#how-to-use-tools)
- [Built-in Tools Reference](#built-in-tools-reference)
  - [Codebase & Search Tools](#codebase--search-tools)
  - [File Operations](#file-operations)
  - [Terminal & Commands](#terminal--commands)
  - [Source Control & Git](#source-control--git)
  - [Testing & Debugging](#testing--debugging)
  - [External & Web](#external--web)
  - [Notebooks](#notebooks)
  - [VS Code Integration](#vs-code-integration)
- [Tool Sets](#tool-sets)
- [Tool Approval & Security](#tool-approval--security)
- [Usage Examples](#usage-examples)

---

## Overview

**Types of Tools:**
- **Built-in Tools**: Provided by VS Code (this document)
- **MCP Tools**: From Model Context Protocol servers
- **Extension Tools**: Contributed by VS Code extensions

**Key Concepts:**
- Tools are referenced with `#` prefix in chat (e.g., `#codebase`, `#fetch`)
- Tools can be enabled/disabled per-request via the tools picker
- Some tools require approval before execution for security
- Tools can be grouped into tool sets for easier management

---

## How to Use Tools

### 1. **Accessing Tools in Chat**

Type `#` in the chat input field to see all available tools:

```
User: Explain the authentication flow #codebase
User: Summarize #fetch https://code.visualstudio.com/updates
User: Fix the issues in #problems
```

### 2. **Enable/Disable Tools**

1. Open Chat view (`Ctrl+Alt+I`)
2. Select **Agent** from the agent picker
3. Click the **Configure Tools** button (gear icon)
4. Select or deselect tools for the current request

### 3. **Explicit Tool References**

Some tools accept parameters directly in the prompt:

```
#fetch <URL>                          - Fetch web content
#githubRepo <owner/repo>              - Search GitHub repository
#file <filename>                      - Reference a specific file
```

### 4. **Tool Sets**

Reference multiple related tools at once:

```
#edit       - Enable file editing tools
#search     - Enable search-related tools
#runCommands - Enable terminal command tools
```

---

## Built-in Tools Reference

### Codebase & Search Tools

#### `#codebase`
**Purpose**: Perform semantic code search in the current workspace  
**Usage**: Automatically finds relevant context for chat prompts  
**Example**:
```
User: How is authentication implemented? #codebase
User: Where is the database connection configured? #codebase
```

#### `#fileSearch`
**Purpose**: Search for files by glob patterns  
**Usage**: Returns file paths matching the pattern  
**Example**:
```
User: Find all CMake files #fileSearch **/*.cmake
User: List all test files #fileSearch **/test/**/*.cpp
```

#### `#textSearch`
**Purpose**: Find text content within files  
**Usage**: Full-text search across workspace files  
**Example**:
```
User: Find all usages of VCPKG_ROOT #textSearch
```

#### `#searchResults`
**Purpose**: Get current search results from the Search view  
**Usage**: Reference existing search results in chat  
**Example**:
```
User: Explain the patterns in #searchResults
```

#### `#usages`
**Purpose**: Find all references, implementations, and definitions  
**Usage**: Combination of "Find All References", "Find Implementation", and "Go to Definition"  
**Example**:
```
User: Show all usages of the install function #usages
```

---

### File Operations

#### `#readFile`
**Purpose**: Read the content of a file in the workspace  
**Usage**: Access file contents for analysis  
**Example**:
```
User: Explain #readFile ports/openssl3/portfile.cmake
```

#### `#createFile`
**Purpose**: Create a new file in the workspace  
**Usage**: Generate and write new files  
**Example**:
```
User: Create a new port for zlib #createFile
```

#### `#createDirectory`
**Purpose**: Create a new directory in the workspace  
**Usage**: Set up folder structures  
**Example**:
```
User: Create build directory structure #createDirectory
```

#### `#editFiles`
**Purpose**: Apply edits to existing files  
**Usage**: Modify file contents programmatically  
**Example**:
```
User: Update version in vcpkg.json to 3.0.0 #editFiles
```

#### `#listDirectory`
**Purpose**: List files in a directory  
**Usage**: Explore folder contents  
**Example**:
```
User: What files are in the ports folder? #listDirectory ports/
```

#### `#edit` (Tool Set)
**Purpose**: Enable all file modification tools  
**Includes**: `#editFiles`, `#createFile`, `#createDirectory`  
**Example**:
```
User: Refactor the port structure #edit
```

---

### Terminal & Commands

#### `#runInTerminal`
**Purpose**: Execute shell commands in the integrated terminal  
**Usage**: Run PowerShell, bash, or other shell commands  
**Security**: Requires approval before execution  
**Example**:
```powershell
User: Install dependencies #runInTerminal
# Executes: vcpkg install --overlay-ports ./ports openssl3
```

#### `#getTerminalOutput`
**Purpose**: Get output from a terminal command  
**Usage**: Retrieve results of previously run commands  
**Example**:
```
User: Check the output of the last build #getTerminalOutput
```

#### `#terminalLastCommand`
**Purpose**: Get the last run terminal command and its output  
**Usage**: Reference recent terminal activity  
**Example**:
```
User: Debug the last command error #terminalLastCommand
```

#### `#terminalSelection`
**Purpose**: Get the current terminal selection  
**Usage**: Reference selected text from terminal  
**Example**:
```
User: Explain this error #terminalSelection
```

#### `#runVscodeCommand`
**Purpose**: Run VS Code commands  
**Usage**: Execute VS Code built-in commands  
**Example**:
```
User: Enable zen mode #runVscodeCommand
User: Format the document #runVscodeCommand
```

#### `#runCommands` (Tool Set)
**Purpose**: Enable terminal command execution and output reading  
**Includes**: `#runInTerminal`, `#getTerminalOutput`, `#terminalLastCommand`, `#terminalSelection`

---

### Source Control & Git

#### `#changes`
**Purpose**: List source control changes  
**Usage**: Get uncommitted changes for analysis  
**Example**:
```
User: Review my changes #changes
User: Generate commit message for #changes
```

#### Commit as Context
**Purpose**: Add commits from source control history as context  
**Usage**: Reference specific commits in prompts  
**Example**:
```
User: Compare current changes to commit abc123
```

---

### Testing & Debugging

#### `#runTests`
**Purpose**: Run unit tests in the workspace  
**Usage**: Execute test suites and get results  
**Example**:
```
User: Run all tests in the project #runTests
```

#### `#testFailure`
**Purpose**: Get unit test failure information  
**Usage**: Diagnose test failures  
**Example**:
```
User: Help fix failing tests #testFailure
```

#### `#findTestFiles`
**Purpose**: Locate test files in the workspace  
**Usage**: Find test suites and test cases  
**Example**:
```
User: Find all test files #findTestFiles
```

#### `#problems`
**Purpose**: Add workspace issues from the Problems panel  
**Usage**: Reference compiler errors, linting issues  
**Example**:
```
User: Fix the issues in #problems
User: Explain the errors #problems
```

---

### External & Web

#### `#fetch`
**Purpose**: Fetch content from web pages  
**Usage**: Retrieve and analyze online documentation  
**Example**:
```
User: Summarize #fetch https://learn.microsoft.com/en-us/vcpkg/
User: Compare to #fetch https://vcpkg.io/
```

#### `#githubRepo`
**Purpose**: Search code in GitHub repositories  
**Usage**: Find patterns and examples in public repos  
**Example**:
```
User: How does routing work in Next.js? #githubRepo vercel/next.js
User: Find vcpkg port examples #githubRepo microsoft/vcpkg
```

#### `#openSimpleBrowser`
**Purpose**: Open the built-in Simple Browser  
**Usage**: Preview locally-deployed web apps  
**Example**:
```
User: Preview the application #openSimpleBrowser http://localhost:3000
```

---

### Notebooks

#### `#newJupyterNotebook`
**Purpose**: Scaffold a new Jupyter notebook  
**Usage**: Generate notebooks based on requirements  
**Example**:
```
User: Create a data analysis notebook #newJupyterNotebook
```

#### `#editNotebook`
**Purpose**: Make edits to notebook files  
**Usage**: Modify notebook cells and content  
**Example**:
```
User: Add data visualization cells #editNotebook
```

#### `#getNotebookSummary`
**Purpose**: Get list of notebook cells and details  
**Usage**: Analyze notebook structure  
**Example**:
```
User: Summarize this notebook #getNotebookSummary
```

#### `#runCell`
**Purpose**: Execute a notebook cell  
**Usage**: Run specific cells in notebooks  
**Example**:
```
User: Run the data loading cell #runCell
```

#### `#readNotebookCellOutput`
**Purpose**: Read output from notebook cell execution  
**Usage**: Analyze cell execution results  
**Example**:
```
User: Explain the output #readNotebookCellOutput
```

#### `#runNotebooks` (Tool Set)
**Purpose**: Enable running notebook cells  
**Includes**: `#runCell`, `#readNotebookCellOutput`, `#getNotebookSummary`

---

### VS Code Integration

#### `#extensions`
**Purpose**: Search for and ask about VS Code extensions  
**Usage**: Find and learn about extensions  
**Example**:
```
User: How to get started with Python? #extensions
User: Find CMake extensions #extensions
```

#### `#installExtension`
**Purpose**: Install VS Code extensions  
**Usage**: Add extensions to the workspace  
**Example**:
```
User: Install the Python extension #installExtension
```

#### `#VSCodeAPI`
**Purpose**: Ask about VS Code functionality and extension development  
**Usage**: Get help with VS Code APIs and features  
**Example**:
```
User: How to create a custom task? #VSCodeAPI
User: Workspace settings API #VSCodeAPI
```

#### `#selection`
**Purpose**: Get the current editor selection  
**Usage**: Reference selected text in the editor  
**Note**: Only available when text is selected  
**Example**:
```
User: Refactor this code #selection
User: Explain #selection
```

---

### Task & Workspace Management

#### `#runTask`
**Purpose**: Run an existing task in the workspace  
**Usage**: Execute tasks defined in tasks.json  
**Example**:
```
User: Run the build task #runTask
```

#### `#createAndRunTask`
**Purpose**: Create and run a new task  
**Usage**: Define and execute ad-hoc tasks  
**Example**:
```
User: Create a task to format all code #createAndRunTask
```

#### `#getTaskOutput`
**Purpose**: Get output from running a task  
**Usage**: Retrieve task execution results  
**Example**:
```
User: Check the build output #getTaskOutput
```

#### `#runTasks` (Tool Set)
**Purpose**: Enable running tasks and reading output  
**Includes**: `#runTask`, `#createAndRunTask`, `#getTaskOutput`

#### `#new`
**Purpose**: Scaffold a new VS Code workspace  
**Usage**: Create preconfigured projects  
**Example**:
```
User: Create a TypeScript project with tests #new
```

#### `#newWorkspace`
**Purpose**: Create a new workspace  
**Usage**: Set up workspace from scratch  
**Example**:
```
User: Create a C++ vcpkg workspace #newWorkspace
```

#### `#getProjectSetupInfo`
**Purpose**: Get setup instructions for different project types  
**Usage**: Scaffold project configurations  
**Example**:
```
User: Setup info for CMake project #getProjectSetupInfo
```

---

### Advanced Tools

#### `#runSubagent`
**Purpose**: Run a task in isolated subagent context  
**Usage**: Improve context management for complex operations  
**Example**:
```
User: Analyze this large codebase independently #runSubagent
```

#### `#todos`
**Purpose**: Track implementation and progress  
**Usage**: Manage todo lists during complex tasks  
**Example**:
```
User: Create a todo list for this feature #todos
```

---

## Tool Sets

Tool sets group related tools for easier management. Reference them with `#` prefix:

### `#search`
**Tools**: `#codebase`, `#fileSearch`, `#textSearch`, `#searchResults`  
**Use Case**: Code and file searching

### `#edit`
**Tools**: `#editFiles`, `#createFile`, `#createDirectory`  
**Use Case**: File creation and modification

### `#runCommands`
**Tools**: `#runInTerminal`, `#getTerminalOutput`, `#terminalLastCommand`, `#terminalSelection`  
**Use Case**: Terminal operations

### `#runTasks`
**Tools**: `#runTask`, `#createAndRunTask`, `#getTaskOutput`  
**Use Case**: Task execution and management

### `#runNotebooks`
**Tools**: `#runCell`, `#readNotebookCellOutput`, `#getNotebookSummary`  
**Use Case**: Notebook operations

---

## Tool Approval & Security

### Why Tools Require Approval

Certain tools require manual approval before execution as a security measure because they can:
- Modify files in your workspace
- Run commands that affect your system
- Access external services
- Make irreversible changes

### Approval Options

When a tool requests approval, you can:
- **Allow**: Run the tool once
- **Allow for Session**: Approve for current session
- **Allow for Workspace**: Approve for this workspace
- **Allow Always**: Approve for all future invocations
- **Skip**: Skip this tool invocation

### Review Tool Parameters

Before approving:
1. Click the chevron next to the tool name
2. Review and edit input parameters
3. Click **Allow** to run with modified parameters

### Auto-Approve Settings

#### Global Auto-Approve (⚠️ Use with Caution)
```json
{
  "chat.tools.global.autoApprove": true
}
```
**Warning**: This disables critical security protections. Only enable if you understand the risks.

#### Terminal Command Auto-Approve
```json
{
  "chat.tools.terminal.autoApprove": {
    // Allow specific commands
    "mkdir": true,
    "vcpkg --version": true,
    "/^git (status|show\\b.*)$/": true,
    
    // Block dangerous commands
    "del": false,
    "rm -rf": false,
    "/dangerous/": false
  }
}
```

**Related Settings**:
- `chat.tools.terminal.enableAutoApprove`: Enable/disable auto-approve functionality
- `chat.tools.terminal.blockDetectedFileWrites`: Detect and block file write commands
- `chat.tools.terminal.ignoreDefaultAutoApproveRules`: Disable all default rules

### Reset Tool Confirmations

To clear all saved tool approvals:
1. Open Command Palette (`Ctrl+Shift+P`)
2. Run: **Chat: Reset Tool Confirmations**

---

## Usage Examples

These examples demonstrate common vcpkg port development workflows using built-in tools. Each example is organized into phases with specific steps and tool invocations.

### Example 1: Complete Environment Check

**Goal**: Verify vcpkg installation and environment configuration

**Phase 1: Verify vcpkg Installation**
```powershell
User: Check vcpkg environment setup

Agent uses:
1. #runInTerminal
   Command: $env:VCPKG_ROOT
   Purpose: Verify VCPKG_ROOT environment variable is set
   
2. #runInTerminal
   Command: vcpkg --version
   Purpose: Check vcpkg executable version and accessibility
   
3. #runInTerminal
   Command: $env:PATH -split ';' | Select-String vcpkg
   Purpose: Verify vcpkg is in system PATH
```

**Phase 2: Inspect vcpkg Directory Structure**
```powershell
Agent uses:
4. #fileSearch
   Pattern: ${VCPKG_ROOT}/scripts/cmake/**/*.cmake
   Purpose: List available CMake helper scripts
   
5. #listDirectory
   Path: ${VCPKG_ROOT}/scripts/cmake
   Purpose: Display CMake scripts organization
   
6. #readFile
   File: ${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake
   Purpose: Review main vcpkg CMake toolchain file
```

**Phase 3: Check Additional Environment Variables**
```powershell
Agent uses:
7. #runInTerminal
   Command: Get-ChildItem Env: | Where-Object Name -like 'VCPKG*'
   Purpose: List all vcpkg-related environment variables
   
8. #terminalLastCommand
   Purpose: Capture output from previous environment variable listing
```

---

### Example 2: Investigate Port Build Failure

**Goal**: Diagnose and fix a failed port installation

**Phase 1: Capture Failure Context**
```powershell
User: Debug the google-dawn port build failure

Agent uses:
1. #terminalLastCommand
   Purpose: Get the last vcpkg install command and its error output
   Expected: vcpkg install google-dawn --overlay-ports ./ports
   
2. #problems
   Purpose: List compiler errors and warnings from Problems panel
   Expected: Undefined symbols, missing headers, linking errors
```

**Phase 2: Analyze Build Configuration**
```powershell
Agent uses:
3. #readFile
   File: ports/google-dawn/portfile.cmake
   Purpose: Review port build script for issues
   
4. #readFile
   File: ports/google-dawn/vcpkg.json
   Purpose: Check port metadata, dependencies, and features
   
5. #fileSearch
   Pattern: buildtrees/google-dawn/**/*.log
   Purpose: Locate detailed build logs
```

**Phase 3: Examine Build Logs**
```powershell
Agent uses:
6. #readFile
   File: buildtrees/google-dawn/config-x64-windows-out.log
   Purpose: Review CMake configuration output
   
7. #readFile
   File: buildtrees/google-dawn/install-x64-windows-out.log
   Purpose: Analyze installation phase errors
   
8. #textSearch
   Query: "error C2" OR "undefined reference"
   Purpose: Find specific error patterns in build output
```

**Phase 4: Search for Solutions**
```powershell
Agent uses:
9. #fetch
   URL: https://github.com/google/dawn/releases/latest
   Purpose: Check if newer version has fixes
   
10. #githubRepo
    Repo: microsoft/vcpkg
    Query: "dawn build failure" OR "dawn windows"
    Purpose: Find similar issues and solutions in vcpkg repository
    
11. #codebase
    Query: "dawn dependencies" OR "webgpu"
    Purpose: Search local ports for similar configurations
```

---

### Example 3: Create New Port from Scratch

**Goal**: Create a new vcpkg port for an open-source library

**Phase 1: Research Target Library**
```powershell
User: Create a port for libsamplerate from GitHub

Agent uses:
1. #fetch
   URL: https://github.com/libsndfile/libsamplerate
   Purpose: Get project overview and build requirements
   
2. #fetch
   URL: https://github.com/libsndfile/libsamplerate/releases/latest
   Purpose: Identify latest stable version and release assets
   
3. #githubRepo
   Repo: libsndfile/libsamplerate
   Query: "CMakeLists.txt" OR "build"
   Purpose: Understand project build system (CMake, Autotools, etc.)
```

**Phase 2: Find Similar Port Templates**
```powershell
Agent uses:
4. #codebase
   Query: "vcpkg_from_github" AND "cmake"
   Purpose: Find existing ports using CMake as reference
   
5. #fileSearch
   Pattern: ports/**/portfile.cmake
   Purpose: List all available port examples
   
6. #readFile
   File: ports/zlib-ng/portfile.cmake
   Purpose: Use a simple, well-structured port as template
   
7. #readFile
   File: ports/zlib-ng/vcpkg.json
   Purpose: Review manifest file structure
```

**Phase 3: Create Port Structure**
```powershell
Agent uses:
8. #createDirectory
   Path: ports/libsamplerate
   Purpose: Create port directory
   
9. #createFile
   File: ports/libsamplerate/portfile.cmake
   Content: Template based on research, including:
   - vcpkg_from_github() call
   - vcpkg_cmake_configure() options
   - vcpkg_cmake_install()
   - vcpkg_copy_pdbs()
   - file(INSTALL) for license
   
10. #createFile
    File: ports/libsamplerate/vcpkg.json
    Content: Manifest with name, version, description, dependencies
```

**Phase 4: Verify and Test**
```powershell
Agent uses:
11. #runInTerminal
    Command: vcpkg install --overlay-ports ./ports libsamplerate
    Purpose: Test port installation
    
12. #terminalLastCommand
    Purpose: Capture installation output for verification
    
13. #problems
    Purpose: Check for any errors or warnings during build
```

---

### Example 4: Update Port to New Version

**Goal**: Update an existing port to a newer upstream version

**Phase 1: Check Current Version**
```powershell
User: Update openssl3 port to version 3.2.0

Agent uses:
1. #readFile
   File: ports/openssl3/vcpkg.json
   Purpose: Get current port version
   Expected: "version": "3.1.0"
   
2. #readFile
   File: ports/openssl3/portfile.cmake
   Purpose: Check current REF (git commit/tag) and SHA512
```

**Phase 2: Research New Version**
```powershell
Agent uses:
3. #fetch
   URL: https://github.com/openssl/openssl/releases/tag/openssl-3.2.0
   Purpose: Get release notes and changelog
   
4. #fetch
   URL: https://github.com/openssl/openssl/blob/openssl-3.2.0/CHANGES.md
   Purpose: Review breaking changes and build requirement updates
   
5. #githubRepo
   Repo: openssl/openssl
   Query: "build" AND "3.2.0" AND "windows"
   Purpose: Check for platform-specific build changes
```

**Phase 3: Calculate New SHA512**
```powershell
Agent uses:
6. #runInTerminal
   Command: |
     $Version = "3.2.0"
     $Url = "https://github.com/openssl/openssl/archive/openssl-${Version}.tar.gz"
     curl -L -o "temp.tar.gz" $Url
   Purpose: Download source archive
   
7. #runInTerminal
   Command: (Get-FileHash -Algorithm SHA512 "temp.tar.gz").Hash.ToLower()
   Purpose: Calculate SHA512 hash for portfile.cmake
   
8. #terminalLastCommand
   Purpose: Capture the calculated hash value
```

**Phase 4: Update Port Files**
```powershell
Agent uses:
9. #editFiles
   File: ports/openssl3/vcpkg.json
   Change: Update "version": "3.1.0" -> "version": "3.2.0"
   
10. #editFiles
    File: ports/openssl3/portfile.cmake
    Changes:
    - Update REF openssl-3.1.0 -> openssl-3.2.0
    - Update SHA512 to newly calculated value
```

**Phase 5: Test Updated Port**
```powershell
Agent uses:
11. #runInTerminal
    Command: vcpkg install --overlay-ports ./ports openssl3 --no-binarycaching
    Purpose: Test installation with new version
    
12. #getTerminalOutput
    Purpose: Monitor installation progress
    
13. #problems
    Purpose: Check for any compilation or linking errors
```

---

### Example 5: Analyze and Fix Compilation Errors

**Goal**: Resolve C++ compilation errors in a port build

**Phase 1: Identify Error Patterns**
```powershell
User: Fix compilation errors in the dawn port

Agent uses:
1. #problems
   Purpose: Get structured list of compilation errors
   Expected: "error C2039: 'struct' is not a member of 'namespace'"
   
2. #terminalLastCommand
   Purpose: Get raw compiler output with file paths and line numbers
   
3. #textSearch
   Query: "error C2" OR "error LNK"
   Include: buildtrees/google-dawn/**/*.log
   Purpose: Find all error occurrences in build logs
```

**Phase 2: Locate Problematic Source**
```powershell
Agent uses:
4. #fileSearch
   Pattern: buildtrees/google-dawn/src/**/*.cpp
   Purpose: List compiled source files
   
5. #readFile
   File: buildtrees/google-dawn/src/dawn-v1.2.3/src/dawn/native/Error.cpp
   Purpose: Read source file mentioned in error
   
6. #codebase
   Query: "similar error pattern" OR "windows compilation fix"
   Purpose: Find similar issues in other ports
```

**Phase 3: Research Upstream Fixes**
```powershell
Agent uses:
7. #fetch
   URL: https://github.com/google/dawn/issues?q=compilation+windows
   Purpose: Check if issue is already reported upstream
   
8. #githubRepo
   Repo: google/dawn
   Query: "windows build" OR "MSVC error"
   Purpose: Find recent commits that might address the issue
   
9. #fetch
   URL: https://github.com/google/dawn/compare/v1.2.3...main
   Purpose: Check diff between current version and latest
```

**Phase 4: Create or Update Patch**
```powershell
Agent uses:
10. #fileSearch
    Pattern: ports/google-dawn/*.patch
    Purpose: List existing patch files
    
11. #readFile
    File: ports/google-dawn/fix-windows-headers.patch
    Purpose: Review existing patches
    
12. #editFiles
    File: ports/google-dawn/fix-compilation.patch
    Purpose: Create new patch file with fix
    Content: Unified diff format with header includes or namespace fixes
```

**Phase 5: Update Portfile and Retest**
```powershell
Agent uses:
13. #editFiles
    File: ports/google-dawn/portfile.cmake
    Change: Add vcpkg_apply_patches() section with new patch
    
14. #runInTerminal
    Command: vcpkg remove google-dawn
    Purpose: Clean previous failed build
    
15. #runInTerminal
    Command: vcpkg install --overlay-ports ./ports google-dawn
    Purpose: Test with applied patches
    
16. #terminalLastCommand
    Purpose: Verify successful build
```

---

### Example 6: Port Dependency Investigation

**Goal**: Understand and resolve port dependency issues

**Phase 1: Analyze Dependency Tree**
```powershell
User: Check why google-dawn requires so many dependencies

Agent uses:
1. #readFile
   File: ports/google-dawn/vcpkg.json
   Purpose: List direct dependencies in manifest
   Expected: "dependencies": ["vulkan", "spirv-tools", ...]
   
2. #runInTerminal
   Command: vcpkg depend-info google-dawn --overlay-ports ./ports
   Purpose: Get full dependency tree
   
3. #terminalLastCommand
   Purpose: Capture dependency graph output
```

**Phase 2: Investigate Each Dependency**
```powershell
Agent uses:
4. #fileSearch
   Pattern: ports/vulkan*/vcpkg.json
   Purpose: Find all vulkan-related ports
   
5. #readFile
   File: ports/vulkan-headers/vcpkg.json
   Purpose: Check vulkan-headers transitive dependencies
   
6. #codebase
   Query: "vulkan" AND "dependency"
   Purpose: Find other ports using vulkan
```

**Phase 3: Check for Circular or Conflicting Dependencies**
```powershell
Agent uses:
7. #textSearch
   Query: "google-dawn"
   Include: ports/**/vcpkg.json
   Purpose: Check if any port depends on google-dawn
   
8. #runInTerminal
   Command: vcpkg search spirv --overlay-ports ./ports
   Purpose: List all spirv-related ports
   
9. #getTerminalOutput
   Purpose: Review available spirv variants
```

**Phase 4: Optimize Dependencies**
```powershell
Agent uses:
10. #fetch
    URL: https://github.com/google/dawn/blob/main/CMakeLists.txt
    Purpose: Check upstream CMake options for optional dependencies
    
11. #editFiles
    File: ports/google-dawn/vcpkg.json
    Changes:
    - Move optional dependencies to "features" section
    - Add feature flags for vulkan, d3d12, metal backends
    
12. #editFiles
    File: ports/google-dawn/portfile.cmake
    Changes:
    - Add vcpkg_check_features() to enable optional deps
    - Add CMake options based on selected features
```

---

### Example 7: Cross-Reference Multiple Documentation Sources

**Goal**: Gather comprehensive information about vcpkg triplet configuration

**Phase 1: Fetch Official Documentation**
```powershell
User: Understand vcpkg triplet system for Windows builds

Agent uses:
1. #fetch
   URL: https://learn.microsoft.com/en-us/vcpkg/users/triplets
   Purpose: Get official triplet documentation
   
2. #fetch
   URL: https://learn.microsoft.com/en-us/vcpkg/users/examples/overlay-triplets-linux-dynamic
   Purpose: Review overlay triplet examples
   
3. #fetch
   URL: https://learn.microsoft.com/en-us/vcpkg/concepts/triplets
   Purpose: Understand triplet concepts and variables
```

**Phase 2: Examine Built-in Triplets**
```powershell
Agent uses:
4. #fileSearch
   Pattern: ${VCPKG_ROOT}/triplets/x64-*.cmake
   Purpose: List all x64 triplet variants
   
5. #readFile
   File: ${VCPKG_ROOT}/triplets/x64-windows.cmake
   Purpose: Review default Windows triplet
   
6. #readFile
   File: ${VCPKG_ROOT}/triplets/x64-windows-static.cmake
   Purpose: Compare static vs dynamic linking settings
```

**Phase 3: Study Custom Triplet Examples**
```powershell
Agent uses:
7. #codebase
   Query: "VCPKG_TARGET_ARCHITECTURE" OR "VCPKG_LIBRARY_LINKAGE"
   Purpose: Find triplet variable usage patterns
   
8. #readFile
   File: triplets/x64-windows.cmake
   Purpose: Review local custom triplet configuration
   
9. #githubRepo
   Repo: microsoft/vcpkg
   Query: "triplet" AND "windows" AND "cmake"
   Purpose: Find community triplet examples
```

**Phase 4: Compare and Synthesize**
```powershell
Agent uses:
10. #textSearch
    Query: "VCPKG_CXX_FLAGS" OR "VCPKG_C_FLAGS"
    Include: triplets/**/*.cmake
    Purpose: Find compiler flag customizations
    
11. Analysis combines:
    - Official documentation (#fetch results)
    - Built-in triplet examples (#readFile results)
    - Local custom triplets (#codebase results)
    - Community patterns (#githubRepo results)
    
    Output: Comprehensive guide to triplet customization
```

---

## Tips and Best Practices

### 1. **Select Only Relevant Tools**
Enable only the tools needed for your specific request to improve response quality and performance.

### 2. **Combine Tools for Better Context**
```
User: Fix compilation errors #problems #codebase #terminalLastCommand
```

### 3. **Use Tool Sets for Common Workflows**
```
User: Refactor this module #edit #search
```

### 4. **Leverage External Tools for Research**
```
User: How does vcpkg handle features? #fetch #githubRepo microsoft/vcpkg
```

### 5. **Review Terminal Commands**
Always review commands before approval, especially those that:
- Modify files (`rm`, `del`, `mv`)
- Install software (`install`, `choco`, `apt`)
- Change system configuration

### 6. **Create Custom Tool Sets**
Define tool sets in `.vscode/tool-sets.jsonc`:
```json
{
  "vcpkg-dev": {
    "tools": ["codebase", "fileSearch", "runInTerminal", "editFiles", "fetch"],
    "description": "Tools for vcpkg port development",
    "icon": "package"
  }
}
```

### 7. **Use Prompt Files with Tool Specifications**
In `.github/prompts/check-env.prompt.md`:
```yaml
---
description: 'Check vcpkg environment'
mode: 'agent'
tools: ['runInTerminal', 'fileSearch', 'terminalLastCommand']
---
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Alt+I` | Open Chat view |
| `Ctrl+Shift+I` | Switch to using agents |
| `Ctrl+N` | Start new chat session |
| `#` | Show tool picker |
| `/` | Show slash commands |
| `@` | Show chat participants |

---

## Additional Resources

- [VS Code Copilot Chat Documentation](https://code.visualstudio.com/docs/copilot/chat/copilot-chat)
- [Chat Tools Guide](https://code.visualstudio.com/docs/copilot/chat/chat-tools)
- [Custom Agents](https://code.visualstudio.com/docs/copilot/customization/custom-agents)
- [Prompt Files](https://code.visualstudio.com/docs/copilot/customization/prompt-files)
- [MCP Servers](https://code.visualstudio.com/docs/copilot/customization/mcp-servers)

---

## Visual Studio (Full IDE)

Visual Studio also supports GitHub Copilot, though with some differences from VS Code:

### Key Differences
- Tool availability may vary between VS Code and Visual Studio
- Visual Studio uses different keyboard shortcuts
- Some tools may have Visual Studio-specific implementations

### Visual Studio Resources
- [GitHub Copilot in Visual Studio](https://learn.microsoft.com/en-us/visualstudio/ide/visual-studio-github-copilot)
- [Visual Studio Copilot Chat](https://learn.microsoft.com/en-us/visualstudio/ide/visual-studio-github-copilot-chat)

---

*Last Updated: November 25, 2025*  
*Document Version: 1.0*
