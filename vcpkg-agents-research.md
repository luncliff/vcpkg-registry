# vcpkg Agent Team: Research

| Item | Value |
|------|-------|
| Status | Draft 2, 2026-11-28 (5 research reports, vcpkg live tests, SDK live probe) |
| Requirements | [vcpkg-agents-requirements.md](./vcpkg-agents-requirements.md) |
| Specifications | [vcpkg-agents-specifications.md](./vcpkg-agents-specifications.md) |

Facts that the requirements and specifications rely on. Each fact has a source: a document URL, a source path with lines, or a local test in this document.

Labels: **Verified** (source read or test run), **Partial** (part confirmed), **Not found** (searched, no evidence).

Source abbreviations:

- `T:` microsoft/vcpkg-tool at tag 2026-09-26, commit `51bf87ca`. Paths under `src/vcpkg/` unless noted.
- `L:` local vcpkg checkout `D:\vcpkg` at commit `9eec002d` (2026-10-16).
- `SDK:` `github.com/github/copilot-sdk/go` v1.0.28 in the Go module cache (the draft's pin).
- `SDK2:` `github.com/microsoft/copilot-sdk/go/v2` v2.0.4 in the Go module cache (the version that works with the installed CLI, §5.1).
- `DOC:` learn.microsoft.com/vcpkg (MicrosoftDocs/vcpkg-docs).

## 1. Test Environment

| Item | Value |
|------|-------|
| Host | Windows, x64 |
| Go | 1.27.0 (`go.mod` requires 1.24) |
| Copilot CLI | 1.0.114 (VS Code shim, WinGet, and npm installs; all the same version) |
| Copilot SDK for Go | v1.0.28 pinned by the draft; v2.0.4 used by the live probe (§5.1) |
| vcpkg tool | 2026-09-26 (`51bf87ca`) |
| vcpkg root | `D:\vcpkg`, commit `9eec002d` |
| CMake, Ninja | 4.4.4, 1.13.2 (system) |
| PowerShell | 7.7.0 |
| Git, gh | 2.56.1, 2.92.0 |
| curl, tar | 8.23.0, bsdtar 3.8.9 |
| Package managers | winget, Chocolatey present; scoop absent |
| Missing | `zip`, `unzip`, `meson` |
| Compiler (from `detect_compiler`) | MSVC 14.52.37025, Visual Studio 18 Community |

Secret handling for this document: `VCPKG_*` variable values on the test host are never recorded. Some of them hold cloud credentials.

## 2. vcpkg Behavior

### 2.1 Locks (Verified)

- vcpkg 2026-09-26 takes exclusive locks on `<installed>/vcpkg/vcpkg-running.lock`, `<buildtrees>/vcpkg-running.lock`, and `<packages>/vcpkg-running.lock` (T:installeddatabase.cpp:102-140; include/vcpkg/installedpaths.h:60-61).
- `install` takes all three in classic and manifest mode, also with `--dry-run` (T:commands.install.cpp:1419-1420). So do `build`, `x-set-installed`, `ci`, `remove`, `upgrade`, and `env`.
- `fetch`, `z-print-config`, and `x-add-version` take no lock.
- `buildtrees` and `packages` default to `<VCPKG_ROOT>/buildtrees` and `<VCPKG_ROOT>/packages` in both modes (T:vcpkgpaths.cpp:238-266, 360-379).
- `--x-install-root`, `--x-buildtrees-root`, and `--x-packages-root` move the locks (T:vcpkgcmdarguments.cpp:350-363).
- Waiting: vcpkg prints `waiting to take filesystem lock`, then gives up after about 1.4 seconds (source; 1.5 s measured in §8.3) with `failed to take lock, another vcpkg may be running against the same directory` and exit code 1. `--x-wait-for-lock` waits without limit (T:base/files.cpp:4297-4360; locales/messages.json:823, 1769). The CMake toolchain passes `--x-wait-for-lock` (L:scripts/buildsystems/vcpkg.cmake:545-547).
- History: until 2026-03-04 the lock was `<VCPKG_ROOT>/.vcpkg-root`, in manifest mode only. Tool PRs #1938 and #1979 (April 2026) moved it.
- `downloads/` is safe for concurrent use: files are written as `<file>.<pid>.part`, then renamed (T:base/downloads.cpp:593-600, 647).

Impact: the ideation's rationale for serial work ("file lock in `VCPKG_ROOT`") is outdated (requirements G-4). Parallel installs are possible with separate roots. The architecture stays serial because of the shared session.

### 2.2 Failure Output (Verified)

- A failed build prints `error: building <spec> failed with: BUILD_FAILED`, then a link to the build-failures guide (T:commands.build.cpp:1808-1825; messages.json:229, 278).
- `See logs for more information:` and the log paths come from the CMake scripts (L:scripts/cmake/vcpkg_execute_required_process.cmake:127-132). The same paths are appended to `buildtrees/<port>/error-logs-<triplet>.txt` (L:scripts/ports.cmake:206).
- Without `--keep-going`, vcpkg writes `<installed>/vcpkg/issue_body.md`, prints a `gh issue create` suggestion when `gh` is on PATH, and exits 1 (T:commands.install.cpp:805-822; commands.build.cpp:2050-2095).
- With `--keep-going`, vcpkg prints a RESULTS summary, writes no issue body, and exits 1 if anything failed.
- `--only-downloads` implies keep-going. In manifest mode it exits 0 (T:commands.install.cpp:1329-1330).

### 2.3 Dry Run and Only-Downloads (Verified)

- `--dry-run` resolves versions, features, and dependencies, prints the plan, and exits 0 (T:commands.install.cpp:1485-1540). DOC commands/install: "Print the install plan, but do not remove or install any packages."
- Classic mode skips ABI hashing and compiler detection. Manifest mode runs `compute_all_abis` first (T:set-installed.cpp:209-210). The locks are taken either way.
- `--only-downloads` runs each build until its first non-download external process call (DOC commands/install). Sources download. Tool acquisition is Partial: `vcpkg_find_acquire_program` may extract tools in download mode (L:scripts/cmake/vcpkg_find_acquire_program.cmake:253).

### 2.4 Configuration Dump and Tool Fetch (Verified)

- `vcpkg z-print-config` (undocumented) prints JSON: `buildtrees`, `default-triplet`, `downloads`, `host-triplet`, `installed`, `manifest-mode-enabled`, `packages`, `vcpkg-root`, `versions-output`, plus `detected-ci-environment` on CI (T:commands.z-print-config.cpp:39-68). It honors `--x-*-root` and `--x-manifest-root`. It does not list overlays or tools.
- `vcpkg fetch <tool>` (undocumented) prints the tool path. It **downloads the tool when no suitable copy exists**, unless `VCPKG_FORCE_SYSTEM_BINARIES` is set (T:tools.cpp:1065-1205; commands.fetch.cpp:20-47). It is not a read-only probe.

### 2.5 ABI Hash (Verified)

- `triplet_abi` is the SHA-256 of the triplet file, then the toolchain hash, then the compiler hash (T:commands.build.cpp:646-704). DOC reference/binarycaching: "The ABI Hash considers: … The triplet file contents and name."
- Any triplet edit, even a comment, changes the ABI of every port of that triplet. Files pulled in with `include()` need `VCPKG_HASH_ADDITIONAL_FILES` (DOC users/triplets).
- Local file `buildtrees/<port>/<triplet>.vcpkg_abi_info.txt` also lists `cmake 4.4.4` and `powershell 7.7.0`. Upgrading a system tool that vcpkg uses changes the ABI too (test P-7).

### 2.6 `x-add-version` (Verified)

- Since tool PR #1616 (release 2025-03-22), it hashes the working tree: it copies the git index, runs `git add -A .`, and runs `git write-tree` (T:vcpkgpaths.cpp:992-1027; base/git.cpp:71-79, 184-201). Committing first is not required.
- DOC commands/add-version: "Any untracked files in the port directory will affect the resulting hash."
- If the tree is already recorded for another version, it warns "checked-in files for X are unchanged from version V … Did you remember to commit your changes?" and exits 1. If the version exists with a different tree, it errors unless `--overwrite-version` is passed (T:commands.add-version.cpp:245-298).
- The 2-commit flow in the ideation is a convention for review and cherry-pick, not a tool need. This repository's history lands each port with `ports/` and `versions/` in one squashed commit (test P-9).

### 2.7 `--editable` and `.clean` Folders (Verified)

- `--editable` works in classic mode only, for packages named on the command line, and disables binary caching for them (T:dependencies.cpp:1133-1144; commands.build.cpp:1393-1397). In manifest mode it is an error (T:commands.install.cpp:1356-1360).
- Without it, `buildtrees/<port>/src/<base>-<hash>.clean` is deleted and re-extracted on every build: "Cleaning sources at … Use --editable to skip cleaning" (L:scripts/cmake/vcpkg_extract_source_archive.cmake:104-118, 153).
- The `.clean` folder holds the source with the port's patches applied.

### 2.8 Compiler Detection (Verified)

- `detect_compiler` is an internal pseudo-port (`L:scripts/detect_compiler/`). No command prints its result.
- It runs during ABI hashing: manifest `install --dry-run`, or `x-set-installed <spec> --dry-run`. Classic `install --dry-run` skips it (T:commands.install.cpp:1532-1535).
- It writes `<buildtrees>/detect_compiler/stdout-<triplet>.log` with `#COMPILER_HASH#`, `#COMPILER_CXX_VERSION#`, `#COMPILER_CXX_ID#`, and `#COMPILER_CXX_PATH#` lines.
- `--feature-flags=-compilertracking` disables it.

### 2.9 Manifest Mode Restrictions (Verified, local)

- Port arguments in manifest mode fail with exit 1: `error: In manifest mode, vcpkg install does not support individual package arguments.` (test P-5).

## 3. Local Probes

| ID | Command | Result |
|----|---------|--------|
| P-1 | `go build`, `go vet` on the draft | Both pass. |
| P-2 | `vcpkg z-print-config` at the registry root | `manifest-mode-enabled: false`; roots under `D:\vcpkg`; triplets `x64-windows`. |
| P-3 | Same, with `--x-manifest-root=test --x-install-root=test-install` | `manifest-mode-enabled: true`; `installed` moves; `buildtrees` and `packages` stay under `D:\vcpkg`. |
| P-4 | `vcpkg install --dry-run --overlay-ports=ports --overlay-triplets=triplets zlib-ng:x64-windows miniaudio:x64-windows` | 0.12 s, exit 0. Plan line: `zlib-ng:x64-windows@2.3.2 -- D:\vcpkg-registry\ports\zlib-ng`. |
| P-5 | `vcpkg install --dry-run --x-manifest-root=test ... zlib-ng` | Exit 1, manifest-mode port-argument error. |
| P-6 | `vcpkg install --dry-run --x-manifest-root=test --x-feature=test --triplet=x64-windows` with overlays | 29 s. Fetched the git registry, ran `detect_compiler`, wrote `x64-windows.vcpkg_abi_info.txt` for planned ports into `D:\vcpkg\buildtrees`. A dry run is not free of side effects. |
| P-7 | Read `buildtrees/farmhash/x64-windows.vcpkg_abi_info.txt` | Keys include `triplet_abi`, `cmake 4.4.4`, `powershell 7.7.0`, `portfile.cmake`, helper script hashes. |
| P-8 | `vcpkg install --dry-run --overlay-ports=ports no-such-port-xyz:x64-windows` | Exit 1: `no-such-port-xyz does not exist`. |
| P-9 | `git show --stat` on recent port commits | Each port lands as one commit with `ports/` and `versions/`; no versions-only commit in the last 200. |
| P-10 | `vcpkg help topics` | 60 topics including `x-add-version`, `x-ci-verify-versions`, `x-set-installed`, `format-manifest`. |
| P-11 | `buildtrees/<port>` file names | `config-<triplet>-out.log`, `config-<triplet>-err.log`, `config-<triplet>-<dbg/rel>-CMakeCache.txt.log`, `config-<triplet>-<dbg/rel>-CMakeConfigureLog.yaml.log`, `install-<triplet>-<dbg/rel>-out.log`, `patch-<triplet>-<n>-out.log`, `extract-out.log`, `stdout-<triplet>.log`, `<triplet>.vcpkg_abi_info.txt`. |

Live install tests (success, failure, lock contention, manifest install, environment variable effects) are in section 8.

## 4. Environment Variables

Sources: [users/config-environment](https://learn.microsoft.com/vcpkg/users/config-environment) (`cfg`, dated 2026-06-25) and related pages, cross-checked with T (`args`: vcpkgcmdarguments.cpp, `paths`: vcpkgpaths.cpp, `proc`: base/system.process.cpp, `bcc`: binarycaching.cpp, `build`: commands.build.cpp, `consts`: contractual-constants.h) and the live tests in §8.6. The documentation lists 24 variables; the tool source declares 78 environment names (`consts:498-577`).

### 4.1 Precedence Rules (Verified)

| Kind | Order (first wins, unless stated) | Source |
|------|-----------------------------------|--------|
| Scalar settings (triplets, downloads root, compression level) | CLI option, then environment variable, then default. The environment only fills values that are still unset. | `args:533-540`; §8.6 |
| vcpkg root | `--vcpkg-root`, then a `.vcpkg-root` found walking up from the working directory, then from the executable, then `VCPKG_ROOT`. A different `VCPKG_ROOT` only warns. | `paths:404-446`; §8.6 L6h |
| Overlay ports and triplets | `--overlay-*`, then `vcpkg-configuration.json`, then `VCPKG_OVERLAY_*`. Separator `;` on Windows, `:` elsewhere. | DOC concepts/package-name-resolution; `paths:127-144`; §8.4, §8.6 |
| Binary sources | All apply, in order: the default source, then `VCPKG_BINARY_SOURCES`, then `--binarysource`. A `clear` entry resets what came before it. | DOC reference/binarycaching: "evaluated first from the environment, then from the command line"; `bcc:3231-3265` |
| Asset sources | `X_VCPKG_ASSET_SOURCES`, then `--x-asset-sources`. | `args:819-829` |
| Feature flags | Per flag, the CLI wins. Setting `x` and `-x` together is an error. | `args:238-286` |

### 4.2 Variable Reference

"ABI" means the variable can change package ABI hashes. "Secret" means its value can hold credentials. "Check" is what the Environment Detector verifies.

| Variable | Purpose and format | ABI | Secret | Check | Status |
|----------|--------------------|-----|--------|-------|--------|
| `VCPKG_ROOT` | vcpkg root, used only when `vcpkg.exe` is not inside a root (`cfg:114-115`). Removed from the build environment. | indirect | no | `.vcpkg-root` exists; `z-print-config` `vcpkg-root`; no mismatch warning | Verified |
| `VCPKG_DOWNLOADS` | Download and tool cache. Absolute, existing folder. Default `<root>/downloads`. An empty value breaks every command. | no | no | exists, writable, not empty | Verified |
| `VCPKG_DEFAULT_TRIPLET`, `VCPKG_DEFAULT_HOST_TRIPLET` | Default target and host triplet. Default `<cpu>-<os>`. The name must exist. An empty or blank value breaks commands. | indirect (triplet file hashed) | no | triplet file resolves | Verified |
| `VCPKG_OVERLAY_PORTS`, `VCPKG_OVERLAY_TRIPLETS` | Overlay folders, list. Relative entries resolve from the working directory. A blank value is ignored. | indirect (files hashed) | no | each folder exists | Verified |
| `VCPKG_BINARY_SOURCES` | Binary cache providers, `;`-separated: `clear`, `default`, `files,<abs path>[,rw]`, `nuget`, `http`, experimental `x-azblob`, `x-aws`, `x-gcs`, ...; `x-gha` is removed and only warns. Not parsed by dry runs (§8.6 L6m). | no | **yes** (SAS, headers, NuGet URLs) | lint offline; `files` folders exist and are writable; SAS `se`/`sp` fields only | Verified |
| `VCPKG_DEFAULT_BINARY_CACHE` | Folder of the default `files` cache. A non-empty value must be an existing absolute folder, or vcpkg fails. Default `%LOCALAPPDATA%\vcpkg\archives` or `$XDG_CACHE_HOME/vcpkg/archives`. | no | no | exists, absolute, writable | Partial (the docs name a different Windows default) |
| `VCPKG_BINARY_CACHE_COMPRESSION_LEVEL` | ZIP level, exactly one digit 0-9. `--binary-cache-compression-level` wins. | no | no | single digit | Verified |
| `X_VCPKG_ASSET_SOURCES` | Asset mirrors: `x-azurl`, `x-script`, `x-block-origin`, `clear`. Parsed for most commands; a syntax error is fatal. Experimental. | no | **yes** | `z-print-config` succeeds; SAS expiry | Verified |
| `VCPKG_NUGET_REPOSITORY`, `X_VCPKG_NUGET_ID_PREFIX`, `VCPKG_USE_NUGET_CACHE` | NuGet repository metadata (falls back to `GITHUB_*` values), package id prefix, use of the NuGet cache (`true` or `1` only). | no | URL may embed credentials | inspect package ids | Verified; prefix Partial |
| `VCPKG_FEATURE_FLAGS` | Comma list. On by default: `binarycaching`, `compilertracking`, `registries`, `versions` (`-name` disables). Off by default: `dependencygraph`. `manifests` cannot be disabled. Unknown names are ignored. | only `-compilertracking` | no | report no-op flags | Partial (`cfg:63` conflicts with the GitHub integration page) |
| `VCPKG_KEEP_ENV_VARS` | `;`-list of names kept in the Windows build environment. "will not be tracked in package ABIs" (`cfg:73-81`). | **no** (§8.6 L6c) | the kept values may be | names exist | Verified |
| `VCPKG_MAX_CONCURRENCY` | Build parallelism, integer > 0, else fatal on first use. Default cores + 1. Exported to ports as `VCPKG_CONCURRENCY`. | no | no | integer > 0 | Verified |
| `VCPKG_FORCE_SYSTEM_BINARIES`, `VCPKG_FORCE_DOWNLOADED_BINARIES` | Presence toggles. System mode skips version checks and applies to every tool. Required on non-x86 Linux and BSD. | indirect (tool versions) | no | tool paths resolve | Partial |
| `VCPKG_DISABLE_METRICS`, `VCPKG_NO_CI` | Presence toggles. A `vcpkg.disable-metrics` file next to the executable also disables metrics. | no | no | none | Verified |
| `VCPKG_VISUAL_STUDIO_PATH` | Visual Studio instance folder, Windows. A triplet variable of the same name wins. | indirect (compiler hash) | no | folder has VC tools | Verified |
| `X_VCPKG_REGISTRIES_CACHE` | Git registry cache. Must be an existing absolute folder, or vcpkg fails. Undocumented. | no | no | exists, writable | Partial (source only) |
| `VCPKG_COMMAND` | Set by vcpkg itself at start; scripts call `$ENV{VCPKG_COMMAND}`. Undocumented. | no | no | do not set | Partial |
| `VCPKG_INSTALLATION_ROOT` | Not read by vcpkg. Set by GitHub-hosted runner images (§7.5). | no | no | root candidate only | Not found (tool) |
| Others | Documented: `CURL_CA_BUNDLE`, `EDITOR`, `VSLANG`. Source only: `VCPKG_SSL_REVOKE_BEST_EFFORT`, `X_VCPKG_IGNORE_LOCK_FAILURES`, `X_VCPKG_RECURSIVE_DATA` (internal; copies asset sources). Obsolete: `VCPKG_USE_SYSTEM_BINARIES`. | | `X_VCPKG_RECURSIVE_DATA` may | | Partial |

### 4.3 Build Environment on Windows (Verified)

vcpkg builds ports in a cleaned environment on Windows only (`proc:587-693`):

- Kept by default: system variables (`SystemRoot`, `TEMP`, `USERPROFILE`, `ProgramFiles`, ...), `http_proxy`, `https_proxy`, `no_proxy`, `GIT_SSH`, `GIT_ASKPASS`, `SSH_AUTH_SOCK`, `ANDROID_NDK_HOME`, `VULKAN_SDK`, `ONEAPI_ROOT`, `CUDA_TOOLKIT_ROOT_DIR`, names starting with `CUDA_PATH`, `TRT_`, `X_TRT_`, and Xbox GDK variables. The allowlist is not documented.
- `PATH` is rebuilt. `VSLANG=1033` is set. `VCPKG_ROOT` is removed.
- Everything else is dropped, including `VCPKG_DOWNLOADS`, `VCPKG_DEFAULT_*`, `X_VCPKG_ASSET_SOURCES`, `CURL_CA_BUNDLE`, `ALL_PROXY`, `GITHUB_*`, and tokens.

Three ways to pass more variables:

| Mechanism | Where | ABI effect |
|-----------|-------|-----------|
| `VCPKG_KEEP_ENV_VARS` | process environment, global, Windows only | none (§8.6 L6c) |
| `VCPKG_ENV_PASSTHROUGH` | triplet variable | tracked: `ENV:<NAME>` with the SHA-256 of the value (`build:2234-2238`) |
| `VCPKG_ENV_PASSTHROUGH_UNTRACKED` | triplet variable | none |

Linux and macOS: no cleaning. Builds inherit the full environment, including unrelated secrets (`proc:736-751`).

Test host example: `VCPKG_KEEP_ENV_VARS` lists three CUDA and TensorRT names. `CUDA_PATH` is already kept by the allowlist prefix; the others need the list. None of them reaches the ABI hash.

### 4.4 Proxy and GitHub Variables

- Downloads use in-process libcurl, which honors `http_proxy`, `https_proxy`, and `no_proxy` (curl documentation). On Windows, without `HTTP_PROXY` and `HTTPS_PROXY`, vcpkg copies the system proxy into builds (`build:523-609`). Partial: not in the vcpkg docs.
- GitHub dependency graph: `VCPKG_FEATURE_FLAGS=dependencygraph`, `GITHUB_TOKEN` with `contents: write`, plus `GITHUB_REPOSITORY`, `GITHUB_REF`, `GITHUB_SHA`, `GITHUB_JOB`, `GITHUB_WORKFLOW`, `GITHUB_RUN_ID`. Manifest mode only (DOC github-integration; `args:582-590`).

### 4.5 CMake Toolchain Variables

The toolchain `scripts/buildsystems/vcpkg.cmake` reads **no** environment variable. It finds the root from its own location and always passes `--triplet` and `--vcpkg-root` (L:398-414, 541-550). Its cache variables:

| Variable | Meaning |
|----------|---------|
| `VCPKG_TARGET_TRIPLET` | Target triplet; auto-detected when unset; changing it needs a fresh cache |
| `VCPKG_HOST_TRIPLET` | Host triplet; passed only when set |
| `VCPKG_MANIFEST_MODE`, `VCPKG_MANIFEST_DIR`, `VCPKG_MANIFEST_INSTALL` | Manifest mode switch, folder, and configure-time install |
| `VCPKG_MANIFEST_FEATURES`, `VCPKG_MANIFEST_NO_DEFAULT_FEATURES` | Become `--x-feature=` and `--x-no-default-features` |
| `VCPKG_INSTALLED_DIR` | Install root; default `${CMAKE_BINARY_DIR}/vcpkg_installed` |
| `VCPKG_OVERLAY_PORTS`, `VCPKG_OVERLAY_TRIPLETS` | Become `--overlay-*` options |
| `VCPKG_INSTALL_OPTIONS`, `VCPKG_FEATURE_FLAGS`, `VCPKG_BOOTSTRAP_OPTIONS` | Extra install arguments, feature flags, bootstrap options |
| `VCPKG_CHAINLOAD_TOOLCHAIN_FILE` | Included first; its text enters the ABI |
| `VCPKG_APPLOCAL_DEPS` | Copies DLLs next to executables on Windows |
| `VCPKG_TRACE_FIND_PACKAGE`, `VCPKG_LOCK_FIND_PACKAGE_<Pkg>` | Trace or lock top-level `find_package` |
| `VCPKG_PREFER_SYSTEM_LIBS` | Deprecated; warns |

These are the variables a manifest-scenario member reads from presets and CMake files (§7.4).

### 4.6 Secret Exposure Paths (Verified)

- vcpkg redacts only registered SAS values, as `*** SECRET ***`. HTTP headers and NuGet values are not registered (`proc:2140-2212`; `bcc:2229-2232`).
- A parse error prints `on expression:` followed by the **whole value** of a binary or asset source (`parse.cpp:37-87`).
- `--debug` prints full command lines and SAS values. `--debug-env` prints every variable and value (`main:298-303`).
- NuGet failures print the NuGet command and its source. azcopy gets the SAS on its command line.
- `X_VCPKG_RECURSIVE_DATA` copies asset sources into every child process.
- Telemetry records only whether some variables are defined, never their values (`metrics.cpp:129-134`).

### 4.7 Implications for the Team

1. Resolve the vcpkg root the way vcpkg does, and report a mismatching `VCPKG_ROOT` as a warning.
2. Run probes with `--disable-metrics`. Never pass `--debug` or `--debug-env`.
3. Report secret-bearing variables as structure only: provider, host, read/write mode, has-secret, SAS expiry and permissions. Lint them before vcpkg parses them, because a parse error echoes the whole value.
4. A path variable is "ready and permitted" when the folder exists, is absolute, and is writable where vcpkg writes.
5. Set-but-empty `VCPKG_DEFAULT_TRIPLET` or `VCPKG_DOWNLOADS` is a blocker. An invalid `VCPKG_MAX_CONCURRENCY`, `VCPKG_DEFAULT_BINARY_CACHE`, or `X_VCPKG_REGISTRIES_CACHE` is fatal at first use.
6. Report no-ops: legacy feature flags, `x-gha`, `VCPKG_USE_SYSTEM_BINARIES`, `VCPKG_PREFER_SYSTEM_LIBS`.
7. Treat `VCPKG_KEEP_ENV_VARS` and `VCPKG_ENV_PASSTHROUGH_UNTRACKED` as untracked build inputs. Two builds with the same ABI hash can differ.
8. On Linux and macOS, every variable reaches port builds. The team starts vcpkg without secrets that vcpkg does not read.
9. On Windows, builds that need credentials, a proxy, or a CA bundle must list those names in `VCPKG_KEEP_ENV_VARS`.
10. Treat vcpkg-tool 2026-09-26 source as the authority where it conflicts with the docs, and recheck after a tool upgrade.

## 5. Copilot SDK for Go

Sources: SDK v1.0.28 source and the SDK repository docs at that tag (full report kept in the session folder as `research-copilot-sdk.md`), SDK2 v2.0.4 source, and a live probe (§5.1).

### 5.1 Version Compatibility and Live Probe (Verified)

| Check | Result |
|-------|--------|
| Draft's SDK v1.0.28 against the installed CLI 1.0.114 | Fails at start: `SDK protocol version mismatch: SDK supports versions 3-3, but server reports version 4.` |
| Latest `github.com/github/copilot-sdk/go` (v1.0.35) | Protocol 3 (`sdk_protocol_version.go`) |
| `github.com/microsoft/copilot-sdk/go/v2` v2.0.4 | Protocol 4. The module moved to the `microsoft` organization; requiring it as `github.com/github/...` fails with `module declares its path as: github.com/microsoft/copilot-sdk/go/v2`. |
| v1 without a runtime path | `managed Copilot runtime unavailable ... set COPILOT_CLI_PATH` |
| v2 API changes | `client.CreateSession(ctx, &copilot.CreateSessionOptions{...})` with grouped options: `Tools: SessionToolOptions{Definitions, AvailableTools, ExcludedTools}`, `Agents: SessionAgentOptions{Definitions, Selected, Default}`, `Permissions: SessionPermissionOptions{OnRequest, Mode}`, `Hooks: SessionHookOptions{Handlers}`. `ClientOptions.Mode` is required (`ModeCodingAgent` or `ModeEmpty`). The default runtime is in-process; the installed CLI needs `Runtime: copilot.SpawnedStdioConnection{Path: <copilot CLI>}`. |

Live probe, 2026-11-28, SDK2 v2.0.4 with CLI 1.0.114, default model, 20 s, 3 premium requests. One session; two tools `tool_alpha` and `tool_beta` in `AvailableTools`; two custom agents `alpha` (`Tools: ["tool_alpha"]`) and `beta` (`Tools: ["tool_beta"]`), both `Infer: false`. Each turn asked: "Call every tool that is available to you".

| Step | Observation |
|------|-------------|
| `Agent.Select("alpha")`, then a turn | Event `subagent.selected`, then one `session.model_change`. Alpha called only `tool_alpha`. **The selected agent's tool allowlist is enforced.** |
| `Agent.Select("beta")`, then a turn | Beta called only `tool_beta`. |
| Hook and permission inputs | `PreToolUseHookInput.AgentID` and `AgentType` were empty. The permission request (`custom-tool`) had no member identity. **Go must track the active member.** |
| `History.Compact` with `Trigger: manual` and `CustomInstructions` | `success=true`, 7 messages removed, 1602-character summary, about 6 s. `session.compaction_start` and `session.compaction_complete` events. |
| `Agent.GetCurrent` after compaction | Still `beta`: **selection survives compaction.** |
| Turn after compaction, no tools | Beta answered with both members' tokens: **shared history survives compaction.** |
| `Agent.Deselect` | Event `subagent.deselected`. |
| `Usage.GetMetrics` | `AgentMetrics` has only the key `main`. **Per-member usage must be computed by the team.** |

### 5.2 Session Sharing and Handoff (Verified, source and docs)

- `Session` methods are safe for concurrent use, but the runtime serializes turns: the default `MessageOptions.Mode` is `enqueue`. The docs state there is no session locking and "concurrent access to same session is undefined" (`docs/features/session-persistence.md:725-735`). The team must hold the baton itself.
- Three ways to switch a member: `Agent.Select`/`Deselect` with per-agent configuration (experimental; no SDK test, verified live in §5.1); live reconfiguration with `Session.SetTools`, `RPC.Options.Update` (available and excluded tools, model, reasoning effort), and `RPC.Permissions.Configure`; or `ResumeSession` with a new configuration, which **replaces the handle** and can mark pending tool calls interrupted unless `ContinuePendingWork` is true.
- Agent RPC: `Select`, `Deselect`, `GetCurrent`, `List`, `Reload`, `SetPrompt`. The selected agent's prompt is injected into the user message, not the system message (`SuppressCustomAgentPrompt` option). `SessionConfig.Agent` (v1) or `SessionAgentOptions.Selected` (v2) pre-selects an agent.
- `Infer: false` keeps the runtime from delegating to a member as a sub-agent.
- `MessageOptions.Source` set to `copilot.MessageSourceAgent("<sender>")` marks a message as coming from another agent (`docs/features/steering-and-queueing.md:36-56`).
- No SDK document or test describes a baton pattern. The docs' multi-agent integrations use one session per agent (`docs/integrations/microsoft-agent-framework.md:276-392`).

### 5.3 Compaction (Verified)

- `RPC.History.Compact(ctx, &SessionHistoryCompactRequest{CustomInstructions, TokenLimit, Trigger})` returns `Success`, `SummaryContent`, `TokensRemoved`, `MessagesRemoved`, and the context window.
- `InfiniteSessions` is on by default: background compaction at 0.80 of the context window, blocking at 0.95. Automatic compaction can run on its own.
- Whether manual compaction needs an idle session: Not found. It was only tested after `SendAndWait` returned, which is when the team compacts.
- Related: `History.SummarizeForHandoff` returns a markdown summary for a handoff; `History.ClearContext` (only from inside a tool handler) clears the conversation but keeps the session identity.

### 5.4 Turns, Tools, and Long Calls (Verified)

- `SendAndWait` adds a 60-second deadline when the context has none. A timeout ends the wait, not the turn. Long turns need a context with a long deadline, or `Send` plus a wait for `session.idle`.
- `SendAndWait` returns the final root assistant message.
- `MessageOptions.ResponseSchema` sends a strict provider-native `json_schema` for one run. The final root `AssistantMessageData.Content` contains the JSON result. SDK v2.0.4 E2E coverage verifies structured output after custom tool execution and verifies `Session.Send` correlation through the final assistant message and `session.idle`.
- Package-level `copilot.SendAndWait[T]` infers the schema and decodes `T`, then follows the same 60-second default when its context has no deadline. `Session.Send` with `ResponseSchema` plus completion events preserves caller-controlled lifetime.
- Tool handlers run in their own goroutine with **no SDK timeout**. `Abort` does not stop a running handler. `ToolInvocation.TraceContext` is cancelled when the call completes or the session disconnects. No runtime limit on external tool calls was found.
- A tool with a nil handler is declaration-only; the host answers later with `RPC.Tools.HandlePendingToolCall`. Option for hours-long installs.
- `Tool` fields: `OverridesBuiltInTool`, `SkipPermission`, `IsTerminal` (a successful call ends the agent turn), `Defer`, `Namespace`. **A `SkipPermission` tool never reaches the permission handler**; only a pre-tool-use deny stops it.
- An empty `ToolResult.TextResultForLLM` is replaced by a dump of the whole struct. Always set it.
- `AvailableTools` and `ExcludedTools` both apply; names may be qualified as `builtin:`, `custom:`, `mcp:`.
- The built-in shell tool is `powershell` on Windows and `bash` elsewhere.

### 5.5 Permissions and Hooks (Verified)

- Permission requests carry only `ToolCallID`, never the agent. Kinds: `custom-tool`, `read`, `write`, `shell`, `url`, `mcp`, `memory`, `hook`, `workflow`, extension kinds.
- Useful fields: `Read.Path`; `Write.FileName`, `Diff`; `Shell.FullCommandText`, `Commands[].ReadOnly`, `PossiblePaths`, `PossibleURLs`, `HasWriteFileRedirection`; `URL.URL`; `CustomTool.ToolName`, `Args`.
- A handler error or nil decision becomes `user-not-available`. Runtime rules can also be set live: `RPC.Permissions.Configure`, `ModifyRules`, `SetMode`.
- Hooks: `OnPreToolUse` (output `PermissionDecision` allow, deny, or ask; `PermissionDecisionReason`; `ModifiedArgs`; `AdditionalContext`), `OnPostToolUse` (`ModifiedResult`), `OnPostToolUseFailure`, `OnUserPromptSubmitted`, `OnSessionStart`, `OnSessionEnd`, `OnErrorOccurred` (`ErrorHandling` retry, skip, abort), `OnAgentStop`, `OnSubagentStart`, `OnSubagentStop`. Agent fields are set for sub-agents only (§5.1).
- Hooks bind at session creation; one closure over the active member serves all members.
- Added in session 2 (source, v2.0.4): `PreToolUseHookInput.WorkingDirectory` (`cwd`) and `ToolName` let a hook pin the working directory per member. `PermissionRequestShell.Commands[].Identifier` is the executable name the runtime parsed; Go never re-parses shell text. `SessionPermissionOptions.Sandbox *rpc.SandboxConfig` (experimental) carries `UserPolicy.Filesystem{ReadonlyPaths, ReadwritePaths, DeniedPaths}` and `UserPolicy.Network{AllowedHosts}`; Windows uses an AppContainer. `CustomAgentConfig.Hooks map[string][]map[string]any` is declarative and per agent, shape undocumented. `Tool.Idempotent` and `Tool.Exposure: explicit` exist. The spec's Go patterns compiled against these types (`go vet`, `go run`).

### 5.6 Events and Usage (Verified)

- `Session.On` handlers run serially on one goroutine behind a 128-event buffer. A blocking handler stalls event delivery. Copy events to a channel and return.
- Events worth logging: `subagent.selected`, `subagent.deselected`, `tool.execution_start`, `tool.execution_complete`, `permission.requested`, `permission.completed`, `session.compaction_start`, `session.compaction_complete`, `session.model_change`, `assistant.usage`, `session.idle`, `session.error`.
- `assistant.usage` is emitted per model call (ephemeral). `Usage.GetMetrics` reports totals; per-agent entries exist for sub-agents only.

### 5.7 System Message, MCP, Skills (Verified)

- `SystemMessageConfig.Mode`: `append` (default; keeps SDK guardrails), `replace` (removes all guardrails), `customize` (per-section overrides). The system message is fixed at create or resume; it cannot change live.
- MCP servers: stdio (`Command`, `Args`, `Env`) or HTTP (`URL`, `Headers`, OAuth); `Tools` filter; per-agent `MCPServers`.
- Skills: `SkillDirectories`, `DisabledSkills`; per-agent `Skills` preload.

## 6. Diagnosis Knowledge

Abbreviations: `M:` line in `T:locales/messages.json`; `V:` the local vcpkg checkout. Fetched 2026-11-28.

### 6.1 Official Guides (Verified)

| Page | Content the Port Doctor uses |
|------|------------------------------|
| [troubleshoot/build-failures](https://learn.microsoft.com/vcpkg/troubleshoot/build-failures) | One log per external process in `buildtrees/<port>/`; read the last log. Download failures (404 means a new URL), hash mismatch ("verify that the downloaded file is secure", then update `SHA512`), `Unable to find a valid toolchain for requested target architecture`, missing system programs, FetchContent failures. |
| [users/versioning-troubleshooting](https://learn.microsoft.com/vcpkg/users/versioning-troubleshooting) | Version database lookups, incomparable schemes, shallow clones, transitive default features (Research §7.3). |
| [users/binarycaching-troubleshooting](https://learn.microsoft.com/vcpkg/users/binarycaching-troubleshooting) | `--debug`; no `Restored ... package(s)` line means no read or an ABI mismatch; compare ABI entries and `#COMPILER_HASH#`. |
| [troubleshoot/asset-caching](https://learn.microsoft.com/vcpkg/troubleshoot/asset-caching) | Mirror and `x-block-origin` errors. |

Only these two pages live under `troubleshoot/`. The guides date from 2024; their message strings drift from the current tool. Prefer `M:` and `V:scripts/cmake` for exact strings. No document covers `error-logs-<triplet>.txt`, `issue_body.md`, or patch failures (Not found).

### 6.2 Stage to Log (Verified)

| Stage | Log in `buildtrees/<port>/` | Source |
|-------|-----------------------------|--------|
| Download | console and `stdout-<t>.log` only | V:scripts/cmake/vcpkg_download_distfile.cmake |
| Extract | `extract-out.log`, `extract-err.log`; sources in `src/<ref>-<hash>.clean` | V:vcpkg_extract_source_archive.cmake:85-124 |
| Patch | `patch-<t>-<n>-out.log`, `patch-<t>-<n>-err.log` | V:z_vcpkg_apply_patches.cmake:19-34 |
| Configure | `config-<t>[-dbg/-rel]-out.log`, `-err.log`, `-CMakeCache.txt.log`, `-CMakeConfigureLog.yaml.log`; Meson `-meson-log.txt.log`; Make `config.log` | V:ports/vcpkg-cmake/vcpkg_cmake_configure.cmake:274-316 |
| Build | `build-<t>-<dbg/rel>-out.log` (CMake, MSBuild); `make-<target>-<t>-<cfg>` | V:ports/vcpkg-cmake/vcpkg_cmake_build.cmake:71 |
| Install | `install-<t>-<cfg>-out.log`; Meson `package-<t>-<cfg>` | V:ports/vcpkg-cmake/vcpkg_cmake_install.cmake:18 |
| Post-build checks | console and `stdout-<t>.log` only | T:postbuildlint.cpp |

- Only `vcpkg_execute_required_process` and `vcpkg_execute_build_process` append to `error-logs-<t>.txt` (V:scripts/ports.cmake:206-207). **Patch, download, hash, and post-build failures never appear there.** The Port Doctor must also read `stdout-<t>.log` and glob `patch-<t>-*-err.log`.
- `issue_body.md` holds host facts plus the tails of the stdout and error logs, up to 64 KiB (T:commands.build.cpp:1894-1955).
- Final result codes: `BUILD_FAILED`, `POST_BUILD_CHECKS_FAILED`, `FILE_CONFLICTS`, `CASCADED_DUE_TO_MISSING_DEPENDENCIES`, unsupported-port results (M:243-278).
- vcpkg retries a build once on transient signatures such as `LNK1102`, `C1060`, `ld terminated with signal 9` (V:vcpkg_execute_build_process.cmake:1-17).

### 6.3 Signatures by Research Axis

| Axis | Signatures (start of message) | Usual fix owner |
|------|-------------------------------|-----------------|
| Build configuration | `Could not find a package configuration file provided by "X"`; `Unable to determine appropriate generator for:`; `configure: error:`; `ninja: build stopped: subcommand failed.`; `Unsupported build architecture ... Please set VCPKG_MESON_(CROSS/NATIVE)_FILE` | Port Editor: portfile options (for example `-DCMAKE_DISABLE_FIND_PACKAGE_X=ON`), features, `vcpkg.json` dependencies; patches last |
| Toolchain | `while detecting compiler information: The log file content at "<path>" is:` (M:698); `in triplet <t>: Unable to find a valid toolchain for requested target architecture <arch>.` (M:1628); `Unable to find a valid Visual Studio instance` (M:711); `RC Pass 1: command "rc ..." failed` (missing Windows SDK); `LNK2038: mismatch detected for 'RuntimeLibrary'`; `undefined reference to` | Blocker (missing component or SDK); Triplet Editor (`VCPKG_PLATFORM_TOOLSET`, `VCPKG_VISUAL_STUDIO_PATH`, flags, `VCPKG_ENV_PASSTHROUGH`); Port Editor (code incompatibility) |
| Installation | `The following files are already installed in <path> and are in conflict with <spec>` (`FILE_CONFLICTS`); `'${debug_config}' does not exist.`; `Couldn't find tool "<n>":`; post-build check warnings (§6.4) | Port Editor: `vcpkg_cmake_config_fixup`, `vcpkg_copy_tools`, `vcpkg_install_copyright`, `file(REMOVE_RECURSE ...)` |
| Misc: download, hash | `<file>.part: error: download from <url> had an unexpected hash`, then `note: Expected:` and `note: Actual  :`, then `Download failed, halting portfile.` (T:base/downloads.cpp:110-116; M:626-630); `<url>: failed: status code 404` | Port Editor (URL, `SHA512`, `port-version`, `versions/`), after verifying provenance; Blocker for 5xx, proxy, stale `downloads/` file |
| Misc: patch, extract | `Applying patch failed: Checking patch <f>... error: while searching for:` (V:z_vcpkg_apply_patches.cmake:34); `Could not find patch:`; `Could not unwrap top level directory from archive` | Port Editor: regenerate or drop the patch; first rule out local edits and line endings |
| Misc: missing tool | `Could not find <program>. Please install it via your package manager` (V:vcpkg_find_acquire_program.cmake:202); `<port> requires autoconf from the system package manager` | Blocker: the user installs the tool |
| Misc: host, supports, versions | `<port> is a host-only port; please mark it as a host port in your dependencies.`; `<feature> is only supported on '<expr>', which does not match <triplet>` (M:1617); `no version database entry` | Port Editor (`"host": true`, `supports`); Blocker (`git pull`, unshallow) |

### 6.4 Post-build Checks (Verified)

- Output: `<portfile.cmake>: warning: <message>`, then `Found <n> post-build check problem(s). These are usually caused by bugs in portfile.cmake or the upstream build system.` (M:783; T:postbuildlint.cpp:1908-1915).
- By default these are warnings and the build succeeds. `--enforce-port-checks` turns them into `POST_BUILD_CHECKS_FAILED` (DOC commands/install; T:commands.install.cpp:1332-1333).
- Each check has a relaxing `VCPKG_POLICY_*` variable (DOC reference/policies), for example `EMPTY_INCLUDE_FOLDER`, `ALLOW_DEBUG_INCLUDE`, `ALLOW_DEBUG_SHARE`, `SKIP_MISPLACED_CMAKE_FILES_CHECK`, `ALLOW_DLLS_IN_LIB`, `ALLOW_EXES_IN_BIN`, `SKIP_COPYRIGHT_CHECK`, `MISMATCHED_NUMBER_OF_BINARIES`, `DLLS_WITHOUT_LIBS`, `SKIP_ARCHITECTURE_CHECK`, `SKIP_CRT_LINKAGE_CHECK`, `ALLOW_EMPTY_FOLDERS`, `SKIP_PKGCONFIG_CHECK`, `SKIP_ABSOLUTE_PATHS_CHECK`, `EMPTY_PACKAGE`.
- Valid policy values: `enabled`, `disabled`, empty. DLL, executable, CRT, and architecture checks run on Windows only.
- Policies are escape hatches. The message usually names the helper that fixes the cause (`vcpkg_cmake_config_fixup()`, `vcpkg_copy_tools`, `vcpkg_fixup_pkgconfig()`).

### 6.5 Known-issue Search (Verified, run 2026-11-28)

1. Offline first: grep `<port>:<triplet>=` in `V:scripts/ci.baseline.txt`. A `fail` entry means an expected CI failure.
2. vcpkg's own hint: `https://github.com/microsoft/vcpkg/issues?q=is%3Aissue+is%3Aopen+in%3Atitle+<port>` (M:266).
3. Titles: the issue template is `[<port>] build failure` with label `category:port-bug`. vcpkg generates `[<port>] build error on <triplet>`. Other labels: `category:vcpkg-bug`, `category:question`, `requires:tool-release`, `depends:upstream-changes`, `Stale`.
4. Closed is not fixed: check `gh issue view <n> --repo microsoft/vcpkg --json stateReason,closedByPullRequestsReferences`. `NOT_PLANNED` with `Stale` means auto-closed.
5. Discussions: GraphQL `search(type: DISCUSSION)` with keywords.
6. Port history: the local clone is shallow, so use `gh api "repos/microsoft/vcpkg/commits?path=ports/<port>&since=<ISO>"`.

Example queries for a hash mismatch:

```text
gh search issues "unexpected hash" --repo microsoft/vcpkg --label category:port-bug --sort updated --limit 6
  -> #55200 [kubazip], #55159 [libunwind] (closed by #55160), #49963 (open), ...
gh search prs "sha512 in:title" --repo microsoft/vcpkg --merged --sort updated --limit 6
  -> #55160 [libunwind] Fix SHA512 of source archive: ports/libunwind/{portfile.cmake,vcpkg.json}, versions/baseline.json, versions/l-/libunwind.json
```

### 6.6 Local Clone Staleness (Verified)

`D:\vcpkg` is a shallow clone: `git rev-parse --is-shallow-repository` prints `true`, and `rev-list --count HEAD` prints `1`. Upstream master is 663 commits ahead of `9eec002d` (GitHub compare API, 2026-11-28). Example: the `libunwind` hash fix #55160 exists upstream but not locally.

Consequences:

- A failure can already be fixed upstream. The Port Doctor checks upstream history before setting goals. An upstream fix becomes either a blocker ("update the vcpkg clone") or, in the registry scenario, an upstream copy of the fixed port into the registry (US-4.2).
- Port history must come from `gh api`, not from the local `git log`.
- A shallow clone fails builtin-baseline lookups for other commits (§7.3).

### 6.7 Triplets (Verified unless noted)

Source: [users/triplets](https://learn.microsoft.com/vcpkg/users/triplets) (`tr`), checked against T and L.

| Variable | Meaning | Note |
|----------|---------|------|
| `VCPKG_TARGET_ARCHITECTURE` | Target CPU: `x86`, `x64`, `arm`, `arm64`, `arm64ec`, `wasm32`, ... | |
| `VCPKG_CRT_LINKAGE` | `dynamic` or `static` CRT | Also picks the Android STL and MinGW `-static` |
| `VCPKG_LIBRARY_LINKAGE` | `static` or `dynamic` | Becomes `BUILD_SHARED_LIBS`; other values are fatal |
| `VCPKG_BUILD_TYPE` | `release` skips debug builds | The tool also accepts `debug` (Partial) |
| `VCPKG_CMAKE_SYSTEM_NAME` | Target OS; empty means Windows desktop | Unknown names fail: `Unable to determine toolchain ... Did you mean to use VCPKG_CHAINLOAD_TOOLCHAIN_FILE?` Emscripten has no default toolchain. |
| `VCPKG_CMAKE_SYSTEM_VERSION` | `CMAKE_SYSTEM_VERSION`; the API level on Android | Android default 21 when unset; built-in Android triplets set 28 |
| `VCPKG_CHAINLOAD_TOOLCHAIN_FILE` | Replaces vcpkg's toolchain | A foreign toolchain ignores `VCPKG_*_FLAGS` |
| `VCPKG_C_FLAGS`, `VCPKG_CXX_FLAGS`, `VCPKG_LINKER_FLAGS` (+ `_DEBUG`, `_RELEASE`) | Compiler and linker flags | C and CXX flags must be set together |
| `VCPKG_CMAKE_CONFIGURE_OPTIONS` (+ `_DEBUG`, `_RELEASE`) | Extra `-D` arguments for every CMake port | Appended after the port's `OPTIONS` |
| `VCPKG_MESON_*`, `VCPKG_CONFIGURE_MAKE_OPTIONS*` | Meson and autotools arguments | |
| `VCPKG_OSX_DEPLOYMENT_TARGET`, `VCPKG_OSX_SYSROOT`, `VCPKG_OSX_ARCHITECTURES`, `VCPKG_INSTALL_NAME_DIR` | Apple settings | iOS simulators use `VCPKG_OSX_SYSROOT iphonesimulator` |
| `VCPKG_PLATFORM_TOOLSET`, `VCPKG_PLATFORM_TOOLSET_VERSION`, `VCPKG_VISUAL_STUDIO_PATH`, `VCPKG_LOAD_VCVARS_ENV` | MSVC selection | |
| `VCPKG_ENV_PASSTHROUGH`, `VCPKG_ENV_PASSTHROUGH_UNTRACKED` | Extra variables in the Windows build environment | Tracked values enter the ABI (§4.3) |
| `VCPKG_HASH_ADDITIONAL_FILES`, `VCPKG_POST_PORTFILE_INCLUDES` | Extra hashed files; CMake files run after the portfile | Absolute existing paths |
| `VCPKG_DEP_INFO_OVERRIDE_VARS`, `VCPKG_DISABLE_COMPILER_TRACKING`, `VCPKG_FIXUP_ELF_RPATH`, `VCPKG_FIXUP_MACHO_RPATH`, `VCPKG_PROVIDED_FORTRAN` | Platform expression overrides, compiler hash removal, RPATH fixups, Fortran | RPATH fixups default on for Linux, BSD, macOS (Partial vs docs) |

- Lookup order: overlay folders (CLI, then configuration, then environment), then built-in `triplets/` (13 files, CI-tested), then `triplets/community/` (91 files, untested). The first file with the name wins (T:vcpkgpaths.cpp:127-144; triplet.cpp:91-103).
- vcpkg prints `loaded overlay triplet from here` or `loaded community triplet from here` (§8.1).
- Triplet names are lowercase letters, digits, and hyphens. A triplet is evaluated several times per run, so it must stay deterministic and fast.
- Per-port customization uses `if(PORT MATCHES "...")` in the triplet.
- Android needs the NDK and `ANDROID_NDK_HOME`; the toolchain fails with `Could not find android ndk` otherwise (L:scripts/toolchains/android.cmake).
- Example of what the Triplet Editor would catch: this registry's `triplets/x64-android.cmake` and `arm64-android.cmake` use `${NDK_API_LEVEL}`, which nothing sets. Partial: read, not built.

### 6.8 Host Dependencies (Verified)

- `"host": true` builds a dependency for the host triplet. Portfiles reach it through `CURRENT_HOST_INSTALLED_DIR` (DOC users/host-dependencies).
- The host triplet comes from `--host-triplet`, `VCPKG_DEFAULT_HOST_TRIPLET`, CMake `VCPKG_HOST_TRIPLET`, or the default `<host cpu>-<host os>`.
- `VCPKG_CROSSCOMPILING` is true whenever the target triplet differs from the host triplet, even `x64-windows-static` on an `x64-windows` host.
- Typical failures: a native-only tool port pulled for the target (`supports: native`); a portfile running target executables while cross-compiling; tools found in `CURRENT_INSTALLED_DIR` instead of the host folder; no host compiler.
- The usual host dependencies are `vcpkg-cmake`, `vcpkg-cmake-config`, `vcpkg-make`, and `vcpkg-tool-meson`.

### 6.9 Tool Acquisition (Verified)

- `vcpkg_find_acquire_program(<NAME>)` looks in `${DOWNLOADS}/tools`, then the system PATH, then downloads when a URL exists. Without a URL it fails: `Could not find <program>. Please install it via your package manager` (L:scripts/cmake/vcpkg_find_acquire_program.cmake:120-262). 27 programs are defined; the docs list 22.
- Through `vcpkg fetch`: 7Z, GIT, NINJA, NUGET, PWSH. Windows downloads only: BISON, FLEX, CLANG, DOXYGEN, GPERF, JOM, NASM, PERL, PYTHON3, PYTHON2, RUBY, SWIG, YASM. Several platforms: GO, BAZEL, PATCHELF, GN, SCONS, GASPREPROCESSOR, MESON. PKGCONFIG uses MSYS2 `pkgconf` on Windows.
- Helper ports `vcpkg-tool-*` (meson, ninja, gn, nodejs, ...) declare `"supports": "native"` and are consumed with `"host": true`.
- Consequence for the Environment Detector: a missing tool is a blocker only when it has no download URL on this host (for example `autoconf` on Linux).

### 6.10 Port Authoring (Verified)

- Version schemes: `version`, `version-semver`, `version-date` (`YYYY-MM-DD[.n]`), `version-string`. Use one and follow upstream's convention. Do not switch to `version-date` only to track a branch head (DOC contributing/maintainer-guide:623-627).
- `port-version`: starts at 0, increases by 1 for each vcpkg-only change, and resets to 0 when the upstream version changes. One bump per change set (DOC users/versioning:94-98).
- `vcpkg format-manifest <path>` (or `--all`) is required; `x-add-version` checks it.
- `vcpkg create` template defects: `"version": ""` is invalid; it uses `vcpkg_download_distfile` with the deprecated `vcpkg_extract_source_archive_ex`; boilerplate comments must go (L:scripts/templates/portfile.in.cmake, vcpkg.json.in). None of the 2879 upstream portfiles uses a deprecated helper; 2325 use `vcpkg_from_github`.
- `vcpkg_from_github`: `REPO`, `REF` (a tag or commit, never a branch), `SHA512`, `HEAD_REF`, `PATCHES`.
- New hash: set `SHA512 0` and build. vcpkg prints `error: failing download because the expected SHA512 was all zeros, please change the expected SHA512 to: <hash>` (T:base/downloads.cpp:1199-1221). `vcpkg hash <file>` also prints it. Hex is lowercase.
- Patches: the official example uses `--editable`, `git init` in `buildtrees`, and `git diff --output` (DOC examples/patching:122-168). Upstream's own agent rules say `git diff --output`, never shell redirection (L:AGENTS.md:5). The ideation limits `--editable`, so the specification uses a scratch copy (§8.9).
- Prefer portfile options over patches: `CMAKE_DISABLE_FIND_PACKAGE_X`, `CMAKE_REQUIRE_FIND_PACKAGE_X`, `vcpkg_check_features`. Configurations not shipped upstream use `unofficial-<port>` and `unofficial::<port>::<target>`.
- `vcpkg_cmake_configure` forces `FETCHCONTENT_FULLY_DISCONNECTED=ON` and warns about unused `-D` variables.

### 6.11 Version Database (Verified)

- `versions/baseline.json`: `{"default": {"<port>": {"baseline": "<version>", "port-version": N}}}`. `versions/<first char>-/<port>.json`: `{"versions": [{"git-tree", "<scheme>", "port-version"}, ...]}`, newest first.
- `x-add-version <port>`: the manifest must be formatted; a new `port-version` must equal the highest recorded plus one; the same version with a new tree fails unless `--overwrite-version`, which replaces the tree in place (T:commands.add-version.cpp:171-353). For registries add `--x-builtin-ports-root=<ports>` and `--x-builtin-registry-versions-dir=<versions>`.
- `x-ci-verify-versions --verbose` checks every port against the database, as upstream CI does. Undocumented.
- Upstream `.gitattributes` is `* -text`. This registry has no such rule, so the tree hash may depend on `core.autocrlf`. Keep LF line endings (Partial: inferred).
- Upstream practice: use `--overwrite-version` only for entries not yet merged.

## 7. Manifest Scenario and CI

Source abbreviations for this section: `VD:` MicrosoftDocs/vcpkg-docs (main), `VC:` microsoft/vcpkg (master), `DC:` dependabot/dependabot-core (main, v0.406.0), `GD:` github/docs (main), `RI:` actions/runner-images (main). Fetched 2026-11-28.

### 7.1 `vcpkg.json` Edits (Verified)

- Strict JSON: no comments or trailing commas. Keys starting with `$` serve as comments (VD:reference/vcpkg-json.md:12-14).
- Dependency objects: `name`, `features`, `default-features` (default true), `host`, `platform`, `version>=` (`1.2.3#7` means port-version 7) (VD:vcpkg-json.md:313-382).
- `overrides`: top level only, one entry per name, exact pin that beats every constraint (VD:users/versioning.md:159-165).
- Which fix to use (VD:users/versioning.concepts.md:65-100):

| Fix | Effect | Use when |
|-----|--------|----------|
| `builtin-baseline` | Floor for every port, including transitive ports | Upgrading in general |
| `version>=` | Floor for one port; the lowest satisfying version wins | One port needs a newer version |
| `overrides` | Exact pin | Incomparable version schemes, a version below the baseline, an exact old version |

- A transitive default feature can only be dropped by adding the port as a direct dependency with `"default-features": false` (VD:users/versioning-troubleshooting.md:216-238).
- Platform expressions: `!`, `|` or `,`, `&`, parentheses; identifiers such as `windows`, `linux`, `osx`, `android`, `ios`, `x64`, `arm64`, `static`, `native` (VD:vcpkg-json.md:468-514; VT:platform-expression.cpp).

### 7.2 `vcpkg-configuration.json` (Verified)

- The file sits next to `vcpkg.json`. Only the top-level project's file counts (VD:reference/vcpkg-configuration-json.md:9-13).
- Fields: `default-registry`, `registries[]` (`kind` builtin, filesystem, git; `baseline`, `reference`, `repository`, `path`, `packages`), `overlay-ports`, `overlay-triplets`. Relative paths resolve from the file's folder (:58-171).
- An embedded `"configuration"` in `vcpkg.json` plus a configuration file is an error: `Ambiguous vcpkg configuration provided by both manifest and configuration file.` (T:locales/messages.json:120).
- A configuration file `default-registry` **wins over** `builtin-baseline` in `vcpkg.json`, with a warning (T:vcpkgpaths.cpp:200-206). An embedded configuration plus `builtin-baseline` is fatal (T:vcpkgpaths.cpp:158-161).
- Overlay order, first match wins: `--overlay-ports`, then configuration `overlay-ports`, then `VCPKG_OVERLAY_PORTS`. The same order applies to triplets, followed by built-in `triplets/` and `triplets/community/` (VD:concepts/overlay-ports.md:16-22; T:vcpkgpaths.cpp:127-144, 660-680). The live tests confirm CLI over env and CLI over configuration (§8.4, §8.6).
- CMake `VCPKG_OVERLAY_PORTS` and `VCPKG_OVERLAY_TRIPLETS` become CLI options, so they outrank configuration entries (VC:scripts/buildsystems/vcpkg.cmake:511-520).

### 7.3 Versioning Errors (Verified)

| Message (start) | Cause | Fix |
|-----------------|-------|-----|
| `error: no version database entry for <port> at <version>` | The version is not in the database of the local clone | Update the clone (`git pull`), or pick a listed version (VD:versioning-troubleshooting.md:42-69) |
| `error: version conflict on <spec>: required <v>, which cannot be compared with the baseline version <v>` | Incomparable version schemes | Same-scheme version, or `overrides` (:95-129) |
| `vcpkg was cloned as a shallow repository` | Shallow clone | `git fetch --unshallow` (:163-189) |
| `... failed to git show versions/baseline.json. This may be fixed by fetching commits with git fetch.` | The baseline commit is missing from the clone; vcpkg never fetches it by itself | `git fetch` in the vcpkg root (T:messages.json:213; registries.cpp:455-507) |
| `... was rejected because it uses "version>=" ... and does not have a "builtin-baseline"` | Constraints without a baseline | Add a baseline (T:messages.json:1743) |

`vcpkg x-update-baseline [--add-initial-baseline] [--dry-run]` moves the builtin baseline to the **local clone's HEAD**, not to a release tag (T:configuration.cpp:694-715).

### 7.4 CMake Integration (Verified)

- Presets set `CMAKE_TOOLCHAIN_FILE` to `<vcpkg root>/scripts/buildsystems/vcpkg.cmake`; vcpkg variables must be set before the first `project()` (VD:users/buildsystems/cmake-integration.md:42-67).
- Configure runs one install (VC:scripts/buildsystems/vcpkg.cmake:505-555):

```text
vcpkg install --triplet <VCPKG_TARGET_TRIPLET> --vcpkg-root <root> --x-wait-for-lock
  --x-manifest-root=<VCPKG_MANIFEST_DIR> --x-install-root=<VCPKG_INSTALLED_DIR>
  [--host-triplet=<VCPKG_HOST_TRIPLET>] [--overlay-ports=<each>] [--overlay-triplets=<each>]
  [--x-feature=<each VCPKG_MANIFEST_FEATURES>] [--x-no-default-features] <VCPKG_INSTALL_OPTIONS>
```

- The toolchain never reads `VCPKG_DEFAULT_TRIPLET`. During configure, only `VCPKG_TARGET_TRIPLET` or auto-detection matters.
- The install log is `${CMAKE_BINARY_DIR}/vcpkg-manifest-install.log` (:557-559). Both manifest files are configure dependencies (:563-568).
- `VCPKG_INSTALLED_DIR` defaults to `${CMAKE_BINARY_DIR}/vcpkg_installed`.

### 7.5 GitHub Actions (Verified unless noted)

- Hosted images set `VCPKG_INSTALLATION_ROOT`, not `VCPKG_ROOT`: `/usr/local/share/vcpkg` on Ubuntu, `C:\vcpkg` on Windows; macOS is Partial (RI:images/*/Readme.md). The clone is made at image build time and never refreshed per job, so newer baselines need `git fetch`.
- `x-gha` binary caching is removed. vcpkg only warns: `The 'x-gha' binary caching backend has been removed` (T:binarycaching.cpp:2168-2171).
- `lukka/run-vcpkg@v11` still defaults `VCPKG_BINARY_SOURCES` to `clear;x-gha,readwrite` when unset, so caching is silently off (dist/index.js@v11:46462, 46818; issues lukka/run-vcpkg#251, #253).
- Recommended replacements: GitHub Packages NuGet, or `files` plus `actions/cache` (VD:consume/binary-caching-github-packages.md; binarycaching.md:146-152). Cloud providers (`x-azblob`, `x-aws`, `x-gcs`, ...) are marked experimental (VD:binarycaching.md:25-33).
- Workflows pass triplets through `matrix.triplet`, `VCPKG_DEFAULT_TRIPLET`, `-DVCPKG_TARGET_TRIPLET`, or `--preset`.

### 7.6 Dependabot (Verified; security updates Partial)

- Configuration: `package-ecosystem: "vcpkg"`, `directory` or `directories`, `schedule.interval` (GD:dependabot-options-reference.md). It reads only `vcpkg.json` and `vcpkg-configuration.json` of the configured folder; an embedded configuration is ignored (DC:vcpkg/file_fetcher.rb:16-29).
- GitHub docs: version updates only; `builtin-baseline` (GD:supported-package-managers.md:305-309).
- Code (newer than the docs): also registry baselines (git, builtin), `version>=`, and OSV security updates (DC:vcpkg/README.md:19-43). Live pull requests in November 2026 bump `builtin-baseline`, registry baselines, and `version>=`.
- The target baseline is the commit of the newest vcpkg **release tag** (for example `2026.10.16` is `9eec002d`) (DC:package_details_fetcher.rb:63-80).
- Trap: Dependabot prefers `builtin-baseline`; vcpkg prefers the configuration file's `default-registry`. A Dependabot bump of the ignored key changes nothing (DC:manifest_baseline.rb:35; §7.2).
- Pull request shape: title like `Bump github.com/microsoft/vcpkg from <old> to <tag> [in /dir]`, branch `dependabot/vcpkg/...`, labels `dependencies` and `vcpkg_package_manager`. The diff is one baseline or `version>=` line, plus JSON re-serialization.

## 8. Live Tests

Run on 2026-11-28 with a throwaway PowerShell script. The fixtures below are enough to repeat every test. Each test uses its own `--x-buildtrees-root`, `--x-packages-root`, and `--x-install-root` under `%TEMP%\vcpkg-agents-probe`, and `--binarysource=clear` unless stated. Downloads use the default `D:\vcpkg\downloads` unless stated.

| Fixture (overlay port) | `vcpkg.json` | `portfile.cmake` |
|------------------------|--------------|------------------|
| `agent-probe-ok` | version `0.1.0` | `message(STATUS "AGENT_PROBE_VAR=[$ENV{AGENT_PROBE_VAR}]")`, then `set(VCPKG_POLICY_EMPTY_PACKAGE enabled)` |
| `agent-probe-fail` | version `0.1.0`; host dependency `vcpkg-cmake` | Copies `src/` to `${CURRENT_BUILDTREES_DIR}/src/probe`, then `vcpkg_cmake_configure` and `vcpkg_cmake_install`. `src/CMakeLists.txt` builds `add_library(probe probe.c)`; `probe.c` returns an undefined symbol. |
| `agent-probe-sleep` | version `0.1.0` | `execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 25)`, then the empty-package policy |
| `agent-probe-prec` | versions `1.0.0`, `2.0.0`, `3.0.0` in three overlay folders (env, CLI, configuration) | Empty-package policy |

### 8.1 Install, List, Remove, Cache (Verified)

| ID | Command | Result |
|----|---------|--------|
| L1-install | `install zlib-ng:x64-windows`, registry overlays, files cache | Exit 0, 19.2 s. Built `vcpkg-cmake`, `vcpkg-cmake-config`, `zlib-ng`. |
| L1-list | `list` | Lists the 3 packages of the isolated install root. |
| L1-install-again | Same install | Exit 0, no build: `The following packages are already installed`. |
| L1-remove | `remove zlib-ng:x64-windows` | Exit 0: `The following packages will be removed`. |
| L1-reinstall-cache | Same install | Exit 0, 2.3 s: `Restored 1 package(s) from <cache>`. |

Output markers the Port Installer can parse:

- `Detecting compiler hash for triplet <t>...` and `Compiler found: <path>`
- `<triplet file>: info: loaded overlay triplet from here`
- `<port folder>: info: installing overlay port from here`
- `Installing <i>/<n> <spec>@<version>...` and `<spec>@<version> package ABI: <hash>`
- `Using source at <buildtrees>/<port>/src/<ref>-<hash>.clean`
- `Restored <n> package(s) from <source>`
- `Starting submission of <spec> to <n> binary cache(s) in the background`
- `Elapsed time to handle <spec>: <time>`

Classic mode never rebuilds an installed port, even after its files change. This confirms the ideation's explicit `vcpkg remove` before install (FR-I-3).

### 8.2 Failure Output (Verified)

L2 installs `agent-probe-fail:x64-windows`: exit 1 after 3.3 s.

```text
CMake Error at scripts/cmake/vcpkg_execute_build_process.cmake:134 (message):
    Command failed: "C:/Program Files/CMake/bin/cmake.exe" --build . --config Debug --target install -- -v -j21
    See logs for more information:
      <bt>\agent-probe-fail\install-x64-windows-dbg-out.log
error: building agent-probe-fail:x64-windows failed with: BUILD_FAILED
See https://learn.microsoft.com/vcpkg/troubleshoot/build-failures?WT.mc_id=vcpkg_inproduct_cli for more information.
Please ensure you're using the latest port files with `git pull` and `vcpkg update`.
Then check for known issues at:
  https://github.com/microsoft/vcpkg/issues?q=is%3Aissue+is%3Aopen+in%3Atitle+agent-probe-fail
You can also submit an issue by running (GitHub CLI must be installed):
  "C:\Program Files\GitHub CLI\gh.exe" issue create -R microsoft/vcpkg --title "[agent-probe-fail] Build failure on x64-windows" --body-file <installed>/vcpkg/issue_body.md
```

- `buildtrees/<port>/error-logs-<triplet>.txt` holds one log path per line.
- `<installed>/vcpkg/issue_body.md` holds: package spec, host triplet, compiler (`MSVC 19.52.37029.0`), CMake version, vcpkg-tool and vcpkg-scripts versions, the reproduce command, and the failure log tail.
- vcpkg prints a ready-made `gh issue create` command. The team must never run it: it files a public issue.
- Build parallelism was `-j21` on this host (default when `VCPKG_MAX_CONCURRENCY` is unset).

### 8.3 Lock Contention (Verified)

L3 holds the locks with a 25 s install of `agent-probe-sleep`, then starts a second command on the same roots.

| ID | Command | Result |
|----|---------|--------|
| L3-contend | `install --dry-run` | Exit 1 after 1.5 s: `note: waiting to take filesystem lock...` (3 times), then `error: failed to take lock, another vcpkg may be running against the same directory`. The lock file is `<installed>\vcpkg\vcpkg-running.lock`. |
| L3-contend-wait | `install --dry-run --x-wait-for-lock` | Exit 0 after 16.2 s; it waited until the holder finished. |

### 8.4 Manifest Mode (Verified)

L4 uses a scratch manifest with `vcpkg-configuration.json` `"overlay-ports": ["./overlay-cfg"]`.

| ID | Command | Result |
|----|---------|--------|
| L4-dryrun-cfg | `install --dry-run` | Configuration overlays work. Path printed as `<manifest>\./overlay-cfg\agent-probe-prec`. |
| L4-dryrun-cli-vs-cfg | Add `--overlay-ports=<overlay-cli>` | The CLI overlay wins over the configuration overlay (2.0.0 over 3.0.0). |
| L4-list | `list` | Lists the manifest install root. |
| L4-remove | `remove agent-probe-ok` | Exit 1: `To remove dependencies in manifest mode, edit your manifest (vcpkg.json) and run 'install'.` |
| L4-install-changed | Bump the overlay port to 0.1.1, then `install` | vcpkg reconciles: `The following packages will be rebuilt`, removes 0.1.0, installs 0.1.1. |
| L4-editable | `install --editable` | Exit 1: `error: The option --editable is not supported in manifest mode.` |

### 8.5 Unsupported Target (Verified)

| ID | Command | Result |
|----|---------|--------|
| L5-osx-dryrun | `install --dry-run agent-probe-ok:arm64-osx` on Windows | Exit 0. Classic dry runs do not detect the compiler, so they cannot catch an unsupported target. |
| L5-osx-install | `install agent-probe-ok:arm64-osx` | Exit 1 after 1.3 s: `error: vcpkg was unable to detect the active compiler's information.` The detect_compiler log shows the CMake failure. |

Side effect: compiler detection for `arm64-osx` printed `A suitable version of ninja was not found (required v1.13.2)` and downloaded ninja into `D:\vcpkg\downloads\tools`, although `vcpkg fetch ninja` returns the Chocolatey ninja (L6e).

### 8.6 Environment Variables (Verified)

| ID | Setting | Result |
|----|---------|--------|
| L6a | `VCPKG_DEFAULT_TRIPLET=x64-windows-static`, `VCPKG_DEFAULT_HOST_TRIPLET=x64-windows-release` | `z-print-config` reports both. |
| L6g | `VCPKG_DOWNLOADS=<dir>` | `z-print-config` reports the new `downloads`. |
| L6h | `VCPKG_ROOT=<non-root>` | Ignored with `warning: The vcpkg D:\vcpkg\vcpkg.exe is using detected vcpkg root D:\vcpkg and ignoring mismatched VCPKG_ROOT environment value ...`. |
| L6h-cli | `--vcpkg-root=<non-root>` | Used. Fails with `error: Invalid triplet: x64-windows` (no triplets there). The CLI option beats detection. |
| L6b | `VCPKG_OVERLAY_PORTS=<env>` | Used (1.0.0 from the env folder). |
| L6b-cli | Same, plus `--overlay-ports=<cli>` | The CLI overlay wins (2.0.0). |
| L6b-list | `VCPKG_OVERLAY_PORTS=<cli>;<env>` | `;`-separated list; the first folder wins. |
| L6c | `AGENT_PROBE_VAR=hello-probe`, without and with `VCPKG_KEEP_ENV_VARS=AGENT_PROBE_VAR` | Without: the portfile sees `[]` (Windows builds run in a cleaned environment). With: `[hello-probe]`. **The ABI files are identical**: kept variables change the build but not the ABI hash. |
| L6e | `vcpkg fetch cmake`, `vcpkg fetch ninja` with an empty downloads root | System `C:\Program Files\CMake\bin\cmake.exe` and `C:\ProgramData\chocolatey\bin\ninja.exe`; nothing downloaded. Same with `VCPKG_FORCE_SYSTEM_BINARIES=1`. |
| L6i | `VCPKG_DEFAULT_TRIPLET` set to a blank | Exit 1: `error: Invalid triplet name. Triplet names are all lowercase alphanumeric+hyphens.` |
| first run | `VCPKG_DEFAULT_TRIPLET` set to an empty string | Exit 1: `error: Invalid triplet:` |
| first run | `VCPKG_DOWNLOADS` set to an empty string | Every command fails: `almost_canonical(""): The filename, directory name, or volume label syntax is incorrect.` |
| L6j | `VCPKG_OVERLAY_PORTS` set to a blank | Ignored. |
| L6l | `VCPKG_FEATURE_FLAGS=registries,binarycaching,manifests,versions` | Accepted silently. |
| L6m | `VCPKG_BINARY_SOURCES=clear;files,Z:\no-such-drive-cache,readwrite` with a classic dry run | Exit 0, no warning. A dry run does not validate binary sources. |

### 8.7 Compiler Detection, Triplet Listing, Port Creation (Verified)

| ID | Command | Result |
|----|---------|--------|
| L7 | `x-set-installed agent-probe-ok:x64-windows --dry-run` (classic) | Exit 0, 2.0 s. Runs compiler detection. `buildtrees/detect_compiler/stdout-x64-windows.log` holds `#COMPILER_HASH#`, `#COMPILER_C_HASH#`, `#COMPILER_C_VERSION#19.52.37029.0`, `#COMPILER_C_ID#MSVC`, `#COMPILER_C_PATH#...`, and the same `CXX` lines. It takes the locks and writes `buildtrees`. |
| L8 | `help triplet --overlay-triplets=<dir>` | Adds a section `Overlay Triplets from "<dir>":`. |
| L9 | `create agent-probe-new <url> --x-builtin-ports-root=<dir>` | Creates `<dir>\agent-probe-new` (not under `D:\vcpkg\ports`), with `portfile.cmake` and `vcpkg.json`. The template computes `SHA512` and uses `vcpkg_download_distfile` with the deprecated `vcpkg_extract_source_archive_ex`. |

### 8.8 Only-Downloads (Verified)

L11: `install --only-downloads zlib-ng:x64-windows` with an empty downloads root. Exit 0, 3 s. Script-only ports install fully. `zlib-ng` stops after its download:

```text
RESULTS
  vcpkg-cmake:x64-windows: SUCCEEDED: 121 ms
  vcpkg-cmake-config:x64-windows: SUCCEEDED: 94.1 ms
  zlib-ng:x64-windows: DOWNLOADED: 674 ms
SUMMARY FOR x64-windows
  SUCCEEDED: 2
  DOWNLOADED: 1
```

It also runs compiler detection, so it catches the unsupported target of L5 before any build.

### 8.9 Patch Workflow (Verified)

L10 tests gap-fill G-9 on `buildtrees/zlib-ng/src/2.3.2-8156fcac72.clean`:

- The `.clean` folder is not a git work tree.
- vcpkg applies patches with `git -c core.longpaths=true -c core.autocrlf=false -c core.filemode=true --work-tree=. --git-dir=.git apply <patch> --ignore-whitespace --whitespace=nowarn --verbose` and `GIT_CONFIG_NOSYSTEM=1` (L:scripts/cmake/z_vcpkg_apply_patches.cmake:9-22).
- A scratch copy with `git init`, a baseline commit, an edit, and `git diff --output=<file>` (all with `core.autocrlf=false` and `GIT_CONFIG_NOSYSTEM=1`) produced an LF-exact patch. vcpkg's apply command applied it cleanly to a fresh copy of `.clean`.
- A first attempt used the system git configuration (`core.autocrlf=true` on Git for Windows) and a PowerShell `Set-Content` write. The patch had CRLF. Plain `git apply --check` rejected it; vcpkg's `--ignore-whitespace` accepted it, but the added lines would carry CRLF.

`make_patch` rules: git with `core.autocrlf=false` and `GIT_CONFIG_NOSYSTEM=1`; write the diff with `--output`; never re-encode it through a shell; verify with vcpkg's apply command on a fresh copy.

### 8.10 Version Commands on This Checkout (Verified)

L12 runs the Baseline Updater's commands read-only: in `D:\vcpkg-registry`, and in a throwaway clone on NTFS under `%TEMP%`.

| ID | Command | Result |
|----|---------|--------|
| L12a | `x-ci-verify-versions --verbose --x-builtin-ports-root=ports --x-builtin-registry-versions-dir=versions` in `D:\vcpkg-registry` | Exit 1 after 0.2 s. vcpkg's internal `git -C ...\ports -c core.autocrlf=false add -A .` failed: `fatal: detected dubious ownership in repository at 'D:/vcpkg-registry' ... on a file system that does not record ownership`. vcpkg then crashed: `internal error: ...commands.ci-verify-versions.cpp(528): Value was null`. |
| L12b | Cause | Drive `D:` is exFAT. The user's `~/.gitconfig` has `safe.directory = *`, so interactive git works. Without `USERPROFILE`, `HOMEDRIVE`, `HOMEPATH`, git cannot find that file and fails the same way. vcpkg's internal git calls do not see the global configuration. |
| L12c | Same command in the NTFS clone | No ownership error. Every port reports `git tree <sha> does not match the port directory`, plus `the dependency vcpkg-cmake does not exist in the version database`. |
| L12d | Cause of the tree mismatch | The system git configuration sets `core.autocrlf=true`, and `.gitattributes` forces LF only for `scripts/*.sh`. Port files are CRLF in the working tree (22 CR, 22 LF in `ports/zlib-ng/vcpkg.json`). vcpkg hashes working-tree bytes with `core.autocrlf=false`; the recorded trees come from LF commits. |
| L12e | Cause of the dependency errors | With `--x-builtin-ports-root`, the registry is the whole builtin registry. Ports from upstream (`vcpkg-cmake`, `vcpkg-cmake-config`) are not in it. `x-ci-verify-versions` assumes a complete registry. |
| L12f | `x-add-version zlib-ng` (same flags) in the NTFS clone | Exit 1: `error: zlib-ng is not properly formatted. Run vcpkg format-manifest ...`. The format check compares bytes, so a CRLF manifest fails. |

Consequences:

- On this host, every version-database command fails until the registry sits on a file system that records ownership, or a `safe.directory` entry reaches vcpkg's git (for example in the system configuration).
- On a CRLF checkout, `x-add-version` either fails the format check or records a tree that no commit has. The ideation's first commit (port files) makes an exact check possible: the recorded `git-tree` must equal `git rev-parse HEAD:ports/<port>`.
- `x-ci-verify-versions` is not a valid check for a registry that depends on upstream ports.

### 8.11 Side Effects of This Session

- `D:\vcpkg\buildtrees`: compiler detection logs and `x64-windows.vcpkg_abi_info.txt` files from the manifest dry run P-6.
- `D:\vcpkg\downloads`: `zlib-ng-zlib-ng-2.3.2.tar.gz` (L1) and `tools\ninja-1.13.2-windows` (L5).
- One Copilot session from the SDK probe (§5.1): 3 premium requests; disconnected at the end.
- No file under `D:\vcpkg\ports` changed. In this repository, only the four documents of this work changed. The scratch folders under `%TEMP%` (probe roots, SDK probe, NTFS clone) are removed at the end of the session.

## 9. Implications for the Specifications

| Fact | Specification impact |
|------|----------------------|
| Locks cover `installed/`, `buildtrees/`, `packages/`, and fail after about 1.5 s (L3) | Serial rationale updated (G-4); lock policy open (G-19); `--x-wait-for-lock` works |
| Manifest mode rejects port arguments, `remove`, and `--editable` (P-5, L4) | Manifest requests carry features (G-7); no `remove` (G-12) |
| Classic mode never rebuilds an installed port (L1) | Explicit `remove` before a retry in the registry scenario (FR-I-3) |
| `.clean` is re-extracted every build; vcpkg applies patches with `--ignore-whitespace` and `core.autocrlf=false` (L10) | Patch workflow uses a scratch copy and byte-exact diffs (G-9) |
| `x-add-version` hashes untracked files | Port Editor leaves no stray files; Baseline Updater checks `git status` first |
| Triplet edits change every port's ABI; kept environment variables do not (L6c) | Triplet edit limit (G-10); the Doctor treats `VCPKG_KEEP_ENV_VARS` as an untracked build input |
| `z-print-config` takes no lock | Safe in `init` and in the Environment Detector |
| `fetch` may download, but returned system tools here (L6e) | Not used as a probe, unless `VCPKG_FORCE_SYSTEM_BINARIES` is set |
| Classic dry runs skip compiler detection; `--only-downloads` and `x-set-installed --dry-run` run it (L5, L7, L11) | Unsupported targets surface at the only-downloads stage; compiler facts come from `x-set-installed --dry-run` |
| Dry runs do not validate binary sources (L6m) | The Environment Detector checks cache folders itself |
| Set-but-empty `VCPKG_DEFAULT_TRIPLET` or `VCPKG_DOWNLOADS` breaks every command | The Environment Detector reports set-but-empty variables as blockers |
| A mismatched `VCPKG_ROOT` is ignored with a warning (L6h) | The Environment Detector reports the warning |
| `error-logs-<triplet>.txt` and `issue_body.md` summarize failures (L2) | Port Installer reads them instead of terminal output |
| vcpkg prints a `gh issue create` command on failure (L2) | No member may run it; `gh_read` allows read-only subcommands only |
| `vcpkg create` honors `--x-builtin-ports-root` and emits a deprecated template (L9) | Port Editor creates ports in the target folder, then modernizes the template |
| SDK v1.0.28 cannot talk to CLI 1.0.114 (protocol 3 vs 4); v2.0.4 can (§5.1) | Implementation targets `github.com/microsoft/copilot-sdk/go/v2` with a spawned CLI runtime |
| `Agent.Select` enforces each member's tool allowlist; selection and shared history survive compaction (§5.1, live) | Members map to custom agents in one session, as the ideation's shared session requires |
| Hook and permission inputs carry no member identity (§5.1, §5.5) | One permission handler and one hook read the Go-side active member |
| `SkipPermission` tools bypass the permission handler (§5.4) | Member tools use ordinary permission handling; `execute_tool` also enforces its command boundary |
| `ResponseSchema` returns strict structured JSON after the model completes its tool work (§5.4) | Each member returns one allowed target and its typed domain payload; Go compacts and forwards it through the explicit channel |
| `IsTerminal` tools end the turn on success (§5.4) | Reserve tools for work capabilities; channel routing uses the structured response |
| `SendAndWait` defaults to a 60 s wait; tool handlers have no timeout (§5.4) | `Send` plus completion events follows caller cancellation; vcpkg commands inherit that lifetime |
| Usage lands under `main` (§5.1) | Per-member usage comes from metric deltas at each handoff |
| vcpkg's internal git ignores the global `safe.directory`; this registry is on exFAT with CRLF port files (§8.10) | The Environment Detector checks the git environment; the Baseline Updater guards the recorded tree against the port commit; `x-ci-verify-versions` is not used |
