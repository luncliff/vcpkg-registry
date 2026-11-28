# vcpkg Agent Team: Requirements

| Item | Value |
|------|-------|
| Status | Draft 2, 2026-11-28 (research and live tests merged) |
| Architecture source | [vcpkg-agents-ideation.md](./vcpkg-agents-ideation.md) (fixed; not redesigned here) |
| Specifications | [vcpkg-agents-specifications.md](./vcpkg-agents-specifications.md) |
| Facts and tests | [vcpkg-agents-research.md](./vcpkg-agents-research.md) |
| Session log | [worknote-vcpkg-agents.md](./worknote-vcpkg-agents.md) |

## 1. Purpose and Scope

The vcpkg agent team is one Go program. It takes a user request about vcpkg and drives it to a verified result or a reported blocker. Typical requests: dry runs, port installs, failure fixes, port updates, port creation, triplet fixes, and version baseline updates.

In scope:

- Two workspace scenarios: registry and manifest (Ideation, "Workspace Scenarios").
- Seven team members that talk over Go channels and share one Copilot session.
- Host systems: Windows, Linux, macOS.

Out of scope:

- Maintaining any specific registry. A registry is only a workspace the team works in.
- Installing system packages. The team searches package managers and reports hints (Gap-fill G-18).
- Parallel installs.

Conventions:

- "Ideation §Name" cites a section of the ideation.
- **Gap-fill** marks a requirement that fills a gap in the ideation. It is pending user confirmation unless marked "Confirmed".
- MUST, SHOULD, and MAY follow RFC 2119.

## 2. Terms

| Term | Meaning |
|------|---------|
| Member | One role of the team: Planner, Environment Detector, Port Installer, Port Doctor, Port Editor, Triplet Editor, Baseline Updater. |
| Shared session | The single Copilot session that all members use. One member takes a turn at a time. |
| Handoff | A channel message that passes the session identity, a goal, and evidence to the next member. |
| Request | Work for the Port Installer: one triplet and a list of ports (registry) or features (manifest, Gap-fill G-7). |
| Port cycle | Port Installer to Port Doctor to Port Editor to Port Installer, for one failed port. |
| Blocker | A condition the team cannot resolve. The Planner reports it with evidence. |
| Ledger | The final per-port result: installed, blocked (with evidence), or skipped. |
| Write scope | The folders and files a member may change. |

## 3. Actors

| Actor | Role |
|-------|------|
| User | Starts the team with a request and receives the final report. |
| Planner | Entry point. Delegates, sequences, and judges finished or blocked. No write access. |
| Environment Detector | Finds paths, tools, triplets, variables, access rights, and host facts. Read-only. |
| Port Installer | Runs `vcpkg list`, `remove`, and `install`. Reads logs. No direct file creation. |
| Port Doctor | Diagnoses failures with logs, documents, and known issues. Read-only. |
| Port Editor | Changes port files and patches. Creates ports. |
| Triplet Editor | Reads, evaluates, creates, and changes triplet files. |
| Baseline Updater | Formats ports, updates the version database, and creates commits. Registry only. |
| External systems | vcpkg tool, Git, GitHub (`gh`), Microsoft Learn, package managers, binary cache providers. |

## 4. Workspace Scenarios

Source: Ideation §Workspace Scenarios and §Design Policy.

| Aspect | Registry scenario | Manifest scenario |
|--------|-------------------|-------------------|
| Typical work | Port development and maintenance; microsoft/vcpkg contribution; self-maintained registry | Repository CI maintenance; Dependabot updates |
| Layout evidence | `ports/`, `versions/`, `triplets/` | `vcpkg.json`, `vcpkg-configuration.json` |
| vcpkg mode | Classic mode with explicit overlays (**Gap-fill G-26**, from "Reference vcpkg classic mode and overlay options" and the Port Installer's commands) | Manifest mode; `--x-manifest-root` when `vcpkg.json` is not at the root; `--x-feature` |
| Install request | `triplet + ports[]` | `triplet + features[]` (Gap-fill G-7; vcpkg rejects port arguments in manifest mode) |
| Default write access | Known port folders and triplet folders | Mostly read-only. `vcpkg.json`, `vcpkg-configuration.json`, and existing overlay folders are editable. New `ports/` or `triplets/` only with explicit user permission. |
| Failed install | Port cycle repairs the port | Reported to the Planner (see Gap-fill G-8) |
| Finish step | Baseline Updater commits | Report only |
| Detection | Automatic, logged with evidence. An explicit switch is undecided (G-20). | Same |

## 5. User Stories

Each story lists scenarios as Given, When, Then. "Flow" names the members and channel messages, using only the relationships in the ideation. A flow that needs a missing relationship cites the gap.

### US-1 Simple Dry Run

As a port maintainer or project developer, I want the team to check a request without building, so that I see unknown ports, unsupported targets, and environment gaps early.

**US-1.1 Registry, known ports, two triplets**

- Given a registry workspace with `ports/`, `versions/`, and `triplets/`.
- When the user asks: "Dry run `zlib-ng` and `miniaudio` for `x64-windows` and `arm64-android`."
- Then the Environment Detector reports scenario `registry`, its evidence, the overlay folders, and the triplet file that wins for each triplet.
- And the Planner sends one request per triplet. The Port Installer runs `vcpkg install --dry-run` with explicit `--overlay-ports` and `--overlay-triplets`.
- And the report lists each planned `port[features]:triplet@version` with its source (overlay path or registry).
- And no port is built. No workspace file changes.
- Flow: User, Planner, Environment Detector, Planner, Port Installer, Planner, User.

**US-1.2 Manifest in a subfolder, with a feature**

- Given a manifest workspace where `vcpkg.json` is not at the repository root.
- When the user asks for a dry run of feature `test` for `x64-windows`.
- Then the Port Installer runs `vcpkg install --dry-run --x-manifest-root=<dir> --x-feature=test --triplet=x64-windows` without port arguments.
- And the report notes that a manifest dry run computes ABI hashes and runs compiler detection, which writes under `buildtrees`.

**US-1.3 Unknown port**

- Given a request that names a port that exists in no overlay and no registry.
- When the Port Installer runs the dry run.
- Then vcpkg fails with `error: ... does not exist` and exit code 1.
- And the Port Installer sends the failure to the Port Doctor.
- And the Port Doctor checks for typos and similar upstream ports, then reports a blocker to the Planner, because a dry run allows no edits.
- And the report names the closest existing ports with evidence.

**US-1.4 Unsupported target on this host**

- Given a Windows host.
- When the user asks for `arm64-osx`.
- Then the classic dry run still passes, because it skips compiler detection (Research §8.5).
- And the `--only-downloads` stage fails at compiler detection: `error: vcpkg was unable to detect the active compiler's information.`
- And the Planner reports a blocker with host facts from the Environment Detector and the vcpkg message (Ideation §Port Doctor -> Planner).

**US-1.5 Environment not ready**

- Given `VCPKG_DEFAULT_BINARY_CACHE` points to a missing or read-only folder, or a required SDK (for example the Android NDK) is missing.
- When the Environment Detector runs.
- Then it reports each problem with evidence.
- And binary cache problems are warnings. A missing SDK is a blocker for the affected triplet only.
- And package manager search results (winget, Chocolatey, apt, Homebrew) appear as hints.

### US-2 Batch Port Update (registry)

As a registry maintainer, I want the team to update several ports to newer upstream releases and verify them on my triplets, so that I get one verified change set per port.

**US-2.1 All ports update and install**

- Given ports A and B have newer upstream releases.
- When the user asks: "Update A and B. Verify on `x64-windows` and `arm64-android`."
- Then the Port Editor sets the new `version`, `REF`, and `SHA512`, and resets `port-version`. How the update goal reaches the Port Editor is open (G-1).
- And the Port Installer removes, then installs, each port for each triplet.
- And the Baseline Updater creates 2 commits per port: port files, then version files.
- And the Planner reports the commits and the ledger.

**US-2.2 One port fails; the port cycle fixes it**

- When port B fails after the update, for example because a patch no longer applies.
- Then the Port Installer sends the failure with `patch-<triplet>-<n>-err.log` and `error-logs-<triplet>.txt` to the Port Doctor.
- And the Port Doctor sends goals to the Port Editor. The Port Editor rebases the patch (G-9).
- And the Port Installer retries B, then resumes the remaining requests.

**US-2.3 One port stays blocked**

- When port B still fails at the cycle limit (G-10).
- Then the Planner reports B as blocked with evidence, keeps A, and the Baseline Updater commits only A.

**US-2.4 Failure on one triplet only**

- When port B fails only for `arm64-android` because the Android API level is too low.
- Then the Port Doctor sends the triplet file, the variable `VCPKG_CMAKE_SYSTEM_VERSION`, and guidance to the Triplet Editor.
- And the Triplet Editor changes the overlay triplet and asks the Planner to reschedule the `arm64-android` request. All ports of that triplet rebuild, because the triplet ABI changed.

**US-2.5 Already at the latest release**

- When no newer release exists.
- Then the port stays unchanged and the report says "up to date".

### US-3 Use the Latest Stable Commit (registry)

As a registry maintainer, I want a port to track the latest stable upstream commit, so that I get fixes before the next release.

**US-3.1 From a release tag to a commit**

- When the user asks to move port A to the latest stable commit.
- Then the Port Editor resolves the commit SHA and date, sets `REF` to the SHA, uses `version-date` with the commit date, updates `SHA512`, and resets `port-version`.
- And the port installs and the Baseline Updater commits it.
- "Stable commit" (**Gap-fill G-15**): the newest commit on the port's `HEAD_REF` branch, or the default branch when the port has none, whose GitHub checks passed (`gh api repos/<owner>/<repo>/commits/<sha>/check-runs`).

**US-3.2 Existing patches no longer apply**

- When the patch step fails on the new source.
- Then the port cycle runs. The Port Editor regenerates the patch from the new sources (G-9).

**US-3.3 New upstream dependency**

- When configure fails at `find_package` for a new dependency.
- Then the Port Doctor names the dependency. The Port Editor adds it to the port's `vcpkg.json`, or US-4 applies when no port exists.

**US-3.4 Already at the latest stable commit**

- Then the port stays unchanged and the report says so.

### US-4 Port Creation Requested by Another Port's Installation

As a maintainer, I want the team to create a missing dependency port when another port needs it, so that the original install succeeds.

**US-4.1 No port exists anywhere (registry)**

- When port A fails because `find_package(X)` fails, and no port X exists in overlays, the registry, or upstream.
- Then the Port Doctor sets goals for a new port X (Ideation §Port Doctor).
- And the Port Editor runs `vcpkg create X <archive-url>`, completes the portfile and `vcpkg.json`, and adds X to A's dependencies.
- And the Port Installer installs X, then retries A.
- And the Baseline Updater commits X before A (G-16).

**US-4.2 Port exists upstream but needs a change**

- Then the Port Editor copies `ports/X` from microsoft/vcpkg into the registry `ports/X`, then applies the change (Ideation: "Hard copy from microsoft/vcpkg upstream ports").

**US-4.3 Vendored sources**

- When port A builds a vendored copy of X with CMake `add_subdirectory`.
- Then the Port Editor creates port X and a patch for A that uses `find_package(X)`.

**US-4.4 Manifest scenario without create permission**

- Then the Port Doctor reports to the Planner: port X is needed, and creating `ports/` needs explicit user permission.

### US-5 Dependabot Baseline Update (manifest)

As a project maintainer, I want the team to verify a Dependabot vcpkg update, so that I can merge it with confidence.

**US-5.1 New baseline installs**

- Given a Dependabot change to `builtin-baseline` in `vcpkg.json`.
- When the user asks to verify it for the CI triplets.
- Then the Environment Detector derives triplets and features from CI workflows and CMake presets.
- And the Planner sends `triplet + features[]` requests. The Port Installer installs. The report confirms success.

**US-5.2 A dependency breaks; overlay folder is writable**

- Then the Port Doctor sends goals to the Port Editor, which fixes the overlay port (G-8). The Port Installer retries.

**US-5.3 A dependency breaks; no write access**

- Then the Port Doctor reports to the Planner with evidence, related upstream issues and pull requests, and options such as a version `overrides` pin or an overlay port.

**US-5.4 Version constraint error**

- When the dry run fails with a versioning error.
- Then the Port Doctor applies the versioning troubleshooting guide. The Port Editor changes `overrides` or constraints in `vcpkg.json` (G-7). The Port Installer retries.

**US-5.5 Dependabot bumped a key that vcpkg ignores**

- Given `vcpkg.json` has `builtin-baseline` and `vcpkg-configuration.json` has a `default-registry`.
- When Dependabot bumps only `builtin-baseline` (Dependabot prefers it; vcpkg prefers the configuration file, Research §7.6).
- Then the Planner reports that the update has no effect, with both file excerpts as evidence.

**US-5.6 The vcpkg clone lacks the new baseline commit**

- Given a shallow or old vcpkg clone (Research §6.6).
- When the new baseline commit is missing from it.
- Then the Environment Detector reports it before any install. The Planner reports a blocker: run `git fetch` in the vcpkg root, which is outside the team's write scope.

### US-6 Reproduce a CI vcpkg Failure (manifest)

As a CI maintainer, I want the team to reproduce and explain a vcpkg failure from CI, so that I can fix the pipeline.

**US-6.1 Same host OS as CI**

- Given a CI workflow that runs vcpkg on the same host OS family.
- When the user asks to reproduce a failed job.
- Then the Environment Detector maps CI settings: triplet, features, overlays, and binary source variable names (never values).
- And the Port Installer reproduces the install. The Port Doctor diagnoses. Fixes follow the write scope.

**US-6.2 Different host OS**

- Then the Planner reports a blocker for local reproduction and lists the CI settings it found.

**US-6.3 CI binary caching is silently off**

- Given a workflow that uses `lukka/run-vcpkg@v11` without `VCPKG_BINARY_SOURCES`, or uses `x-gha`.
- Then the report contains a warning: `x-gha` is removed, so the job builds everything from source (Research §7.5). Binary caching problems stay warnings (FR-T-11).

### US-7 Triplet Adjustment

As a maintainer, I want the team to fix triplet settings that block installs, so that ports build for my targets.

**US-7.1 macOS minimum SDK**

- When the Port Doctor finds "minimum SDK 12.0 required" for `x64-osx`.
- Then it sends `x64-osx.cmake`, the variables, and guidance to the Triplet Editor (Ideation example). The Triplet Editor sets the deployment target. The Planner reschedules.

**US-7.2 Android API level**

- Same as US-2.4.

**US-7.3 A built-in triplet needs a change**

- Then the Triplet Editor creates an overlay copy in a writable overlay folder.
- And the Environment Detector confirms which triplet file wins. The Planner reschedules.

**US-7.4 Host dependency failure**

- When a host tool port fails while cross-compiling.
- Then the Triplet Editor asks the Environment Detector for host facts (host triplet, compilers), then changes the host triplet overlay or reports a blocker.

### US-8 Environment and Runtime Blockers

As any user, I want clear reports of conditions the team cannot fix, so that I know what to install or change.

**US-8.1 Missing build tool that vcpkg can acquire** (for example Meson)

- Then no blocker. The Environment Detector reports that vcpkg will acquire the tool.

**US-8.2 Missing SDK** (Android NDK, CUDA, a Visual Studio component)

- Then a blocker for the affected triplet, with package manager hints.

**US-8.3 Binary cache failure** (for example an expired token)

- Then a warning. Installs continue.

**US-8.4 Another vcpkg process holds a lock**

- Then the Port Installer waits or reports, per G-19. Without `--x-wait-for-lock`, vcpkg gives up after about 1.5 seconds with `failed to take lock, another vcpkg may be running against the same directory` (Research §8.3).

**US-8.5 A set-but-empty variable**

- Given `VCPKG_DEFAULT_TRIPLET` or `VCPKG_DOWNLOADS` is set to an empty value.
- Then every vcpkg command fails (Research §8.6). The Environment Detector reports a blocker that names the variable.

**US-8.6 Version commands cannot work on this checkout (registry)**

- Given a registry on a file system without ownership records (exFAT, FAT, a network share), or with CRLF port files in the working tree.
- When the run would end with the Baseline Updater.
- Then the Environment Detector reports it before any install: vcpkg's own git calls fail with `detected dubious ownership`, or `x-add-version` fails the format check or records a tree that no commit has (Research §8.10).
- And the Planner reports the Baseline Updater step as blocked, with the fix options: move the registry to a file system that records ownership, add a `safe.directory` entry that vcpkg's git can see, and keep port files LF.

## 6. Functional Requirements

### 6.1 Team-wide

| ID | Requirement | Source |
|----|-------------|--------|
| FR-T-1 | Members MUST communicate only through Go channels, following CSP. | Ideation §Agent Team Members |
| FR-T-2 | Members MUST share one Copilot session. Only one member takes a turn at a time. The session identity MUST travel with each handoff. | §Definitions; Q&A "Context compaction?" |
| FR-T-3 | A member MUST compact the session before it sends a message on a channel. | Q&A "Context compaction?" |
| FR-T-4 | Messages MUST state goals and evidence, not step-by-step instructions. | Q&A "Why the Planner comes first?" |
| FR-T-5 | Every member MAY run `vcpkg help`, `vcpkg help <topic>`, and `vcpkg help <command>` to correct its arguments. | §Agent Team Members |
| FR-T-6 | Only members with write access MAY change files, and only inside their write scope. All other tool use MUST be read-only. | §Agent Team Members |
| FR-T-7 | The port cycle MUST handle one port at a time. | §Design Policy |
| FR-T-8 | The team MUST use one model for all members. | Q&A "Context compaction?" |
| FR-T-9 | The team MUST detect the scenario automatically and log the evidence. | §Workspace Scenarios |
| FR-T-10 | **Gap-fill G-6.** Write scopes MUST come from CLI flags parsed in `init`, with scenario defaults. The prompt MAY narrow them. It MUST NOT widen them. | §Design Policy; §Implementation Styles |
| FR-T-11 | Binary caching problems MUST be warnings, never errors. | §Port Doctor |
| FR-T-12 | **Gap-fill G-13.** No member MAY write a secret value into logs, messages, or model context. | Research §4.6 |
| FR-T-13 | **Gap-fill G-25.** No member MAY write to remote services: no push, no pull request, no issue, no comment. vcpkg prints a `gh issue create` command on failure; no member runs it. | Research §8.2 |
| FR-T-14 | Each model turn MUST return a structured result selecting one allowed outbound relationship and carrying its `Handoff` or final report. Go MUST compact the shared session before routing that value through the existing channel. Tools remain work capabilities. | Ideation §Agent Relationships; Research §5.4 |

### 6.2 Planner

| ID | Requirement | Source |
|----|-------------|--------|
| FR-P-1 | The Planner MUST be the entry point for the user request. | §Relationships |
| FR-P-2 | The Planner MUST delegate scenario and availability detection to the Environment Detector. | §Planner |
| FR-P-3 | The Planner MUST decide the install sequence from detection results and send requests to the Port Installer in sequence. | §Planner; §Planner -> Port Installer |
| FR-P-4 | The Planner MUST decide whether the task is finished or blocked. | §Planner |
| FR-P-5 | The Planner MUST NOT have write access. | Q&A "Why the Planner comes first?" |
| FR-P-6 | On a reinstall request from the Triplet Editor, the Planner MUST reschedule the affected requests as if they came from the user. | §Triplet Editor -> Planner |
| FR-P-7 | In the registry scenario, after all installs succeed, the Planner MUST hand the session to the Baseline Updater and resume when it returns. | §Planner <-> Baseline Updater |
| FR-P-8 | The Planner MUST report results and blockers to the user. | §Port Installer -> Planner |
| FR-P-9 | **Gap G-1.** Update requests (US-2, US-3) MUST reach the Port Editor. The channel is open. | User Stories titles |

### 6.3 Environment Detector

| ID | Requirement | Source |
|----|-------------|--------|
| FR-E-1 | MUST locate `buildtrees`, `packages`, `installed`, `downloads`, and binary caches. MUST honor designated `--x-buildtrees-root`, `--x-packages-root`, and `--x-install-root`. | §Environment Detector |
| FR-E-2 | MUST locate ports (overlays, registry, vcpkg defaults) and triplets (built-in, community, overlay), and report which triplet file wins. | §Environment Detector |
| FR-E-3 | MUST verify that set `VCPKG_*` variables are ready and permitted (Research §4.2, §4.7). | §Environment Detector |
| FR-E-4 | MUST run tools to get absolute paths and versions. A PATH lookup alone is not enough. | §Planner <-> Environment Detector |
| FR-E-5 | Its commands MUST NOT write. **Gap-fill G-14:** the only exception is one transient probe file per planned write folder, created and deleted to check write access. | §Environment Detector |
| FR-E-6 | MAY search package managers (apt, winget, Chocolatey, Homebrew) and report installable tools. | §Environment Detector |
| FR-E-7 | MUST report host and target facts, including compiler detection, and estimate the triplets the plan will use. | §Planner <-> Environment Detector |
| FR-E-8 | MUST report readable and writable folders, and access to web resources (GitHub, Microsoft Learn). | §Planner <-> Environment Detector |
| FR-E-9 | MUST answer host-fact requests from the Triplet Editor. | §Triplet Editor <-> Environment Detector |
| FR-E-10 | Its detection procedure MUST match the deterministic checks in `init`, so later members can repeat it as a tool. | Q&A "Why we separate Environment Detector" |
| FR-E-11 | MUST report variable names and status. MUST NOT report values of secret-bearing variables (G-13). | Gap-fill |

### 6.4 Port Installer

| ID | Requirement | Source |
|----|-------------|--------|
| FR-I-1 | MUST build install commands from each request. | §Port Installer |
| FR-I-2 | MUST run `vcpkg list` to record installed ports. | §Port Installer |
| FR-I-3 | MUST run an explicit `vcpkg remove` before install in the registry scenario. Classic mode never rebuilds an installed port (Research §8.1). **Gap-fill G-12:** not in manifest mode; vcpkg rejects `remove` there and reconciles the install tree itself (Research §8.4). | §Port Installer |
| FR-I-4 | MUST run `--dry-run`, then `--only-downloads`, before the full install, to detect failures early. | §Port Installer |
| FR-I-5 | MUST run the full install in the foreground. It MAY take hours. | §Port Installer |
| FR-I-6 | MUST NOT read terminal output. MUST read vcpkg log files instead. | §Port Installer |
| FR-I-7 | MUST stack requests, resume the next one after success, and report to the Planner when all succeed. **Gap-fill G-11:** requests run in arrival order; a retry runs before the remaining requests. | §Port Installer; §Port Installer -> Port Installer |
| FR-I-8 | On failure, MUST hand the session to the Port Doctor with the failed port, the triplet, and the log paths vcpkg reported. | §Port Installer |
| FR-I-9 | MUST have read access only. Intermediate files come only from tool invocation. No direct file creation. | §Port Installer Constraints |
| FR-I-10 | On a retry from the Port Editor, MUST install the changed port, then resume. | §Port Editor -> Port Installer |
| FR-I-11 | After a triplet change, MUST clean up the installed packages of the affected requests before reinstalling. | §Triplet Editor -> Planner |
| FR-I-12 | MUST report failures that the port cycle cannot resolve to the Planner. | §Port Installer -> Planner |

### 6.5 Port Doctor

| ID | Requirement | Source |
|----|-------------|--------|
| FR-D-1 | MUST diagnose configure, build, and install failures with the official troubleshooting guides. | §Port Doctor |
| FR-D-2 | MUST search microsoft/vcpkg issues, discussions, and pull requests for known fixes. | §Port Doctor |
| FR-D-3 | MUST research along these axes: build configuration, toolchain, installation, misc. | §Port Installer -> Port Doctor |
| FR-D-4 | MUST produce a diagnosis with evidence, and goals that let the Port Installer start again with confidence. | §Port Installer -> Port Doctor |
| FR-D-5 | MUST route the result: port goals to the Port Editor, triplet goals to the Triplet Editor, blockers to the Planner. In the manifest scenario, it reports to the Planner. **Gap-fill G-8:** route by write permission of the fix target. | §Port Doctor; §Doctor -> Planner |
| FR-D-6 | MUST scan buildtrees for missing dependency ports and MAY set goals for a new port: upstream copy, new port, or vendored source turned into a port. | §Port Doctor |
| FR-D-7 | MUST read the `*.clean` source folders in `buildtrees` directly. | §Design Policy |
| FR-D-8 | MUST have read-only local access. MAY use web search and optional read-only MCP tools (Slack, Confluence, GitHub Enterprise). | §Port Doctor Constraints |
| FR-D-9 | MUST separate facts, observations, and interpretations, and cite each source. | Q&A "Why the Planner comes first?" (evidence) |

### 6.6 Port Editor

| ID | Requirement | Source |
|----|-------------|--------|
| FR-PE-1 | MAY read other ports for reference. | §Port Editor |
| FR-PE-2 | MUST edit `portfile.cmake`, `vcpkg.json`, and other files only inside the target port folder. | §Port Doctor -> Port Editor |
| FR-PE-3 | MUST create patches from the current buildtrees. **Gap-fill G-9:** from a scratch copy of the `.clean` folder. | §Port Editor; §Port Doctor -> Port Editor |
| FR-PE-4 | MUST create new ports with `vcpkg create`, then improve the template. | §Port Editor |
| FR-PE-5 | MUST update `version` and `port-version`. MUST leave them if they were already changed. | §Port Doctor -> Port Editor |
| FR-PE-6 | MAY use web search for project details, releases, source archives, and the build system. | §Port Editor |
| FR-PE-7 | MUST hand the session to the Port Installer after changes. | §Port Editor -> Port Installer |
| FR-PE-8 | MUST follow the tips of the current repository. **Gap-fill G-17:** follow the repository's guides and patch conventions, and start each new patch with a short "why" header. | §Port Editor |
| FR-PE-9 | **Gap-fill G-7.** In the manifest scenario, owns changes to `vcpkg.json`, `vcpkg-configuration.json`, and overlay ports. | §vcpkg manifest scenario |

### 6.7 Triplet Editor

| ID | Requirement | Source |
|----|-------------|--------|
| FR-TE-1 | MUST read the triplet files in use. | §Triplet Editor (first) |
| FR-TE-2 | MUST fetch and read official vcpkg documents. | §Triplet Editor (first) |
| FR-TE-3 | MUST evaluate fix candidates and their effect on the ports being installed. | §Triplet Editor (first) |
| FR-TE-4 | MUST create or change the triplet file from the Port Doctor's goal (file, variables, guidance) and make the next tasks use it. | §Triplet Editor (second); §Port Doctor -> Triplet Editor |
| FR-TE-5 | MAY ask the Environment Detector for host facts. | §Triplet Editor <-> Environment Detector |
| FR-TE-6 | After a change, MUST ask the Planner to reschedule the affected requests, because the binary cache entries are no longer valid. | §Triplet Editor -> Planner |

### 6.8 Baseline Updater (registry only)

| ID | Requirement | Source |
|----|-------------|--------|
| FR-B-1 | MUST format the port files and update the version database, with the registry's scripts when present, or the equivalent vcpkg commands. | §Baseline Updater |
| FR-B-2 | MUST create 2 commits per port: port files first, then version files. | §Baseline Updater |
| FR-B-3 | MUST order the commits "based on the recent changes". **Gap-fill G-16:** dependencies first, then the team's change order. | §Baseline Updater |
| FR-B-4 | MUST keep each port's changes separate so that they can be cherry-picked. | §Planner <-> Baseline Updater |
| FR-B-5 | MUST hand the session back to the Planner when done. | §Planner <-> Baseline Updater |

## 7. Non-Functional Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| NFR-1 | Serial execution: one member active, one vcpkg process started by the team at a time. | §Definitions |
| NFR-2 | Long installs: no member timeout may end an install before the install budget. | §Port Installer |
| NFR-3 | Context: each handoff message MUST be self-contained (goal, evidence, paths), so that compaction loses nothing the next member needs. | Q&A "Context compaction?" |
| NFR-4 | Logging: structured `log/slog` output with the member name. INFO by default, DEBUG with `--verbose`. Log the scenario evidence, every handoff, every tool call, and session usage. | §Workspace Scenarios; draft style |
| NFR-5 | Safety: permission handlers deny by default. Hooks validate tool arguments. Read-only members get read-only command subsets. | §Agent Team Members |
| NFR-6 | Secrets (Gap-fill G-13): vcpkg child processes keep the variables vcpkg reads, because binary caching needs credentials. Secrets vcpkg does not read are removed from them. Model-visible output is redacted. vcpkg never runs with `--debug` or `--debug-env`. | Research §4.6, §4.7 |
| NFR-7 | Cache: the team MUST NOT disable binary caching to work around a failure. It SHOULD limit `--editable`. | §Design Policy |
| NFR-8 | Portability: Windows, Linux, macOS. Native, current shells (PowerShell, Bash, Zsh). | §Tools |
| NFR-9 | Evidence: every diagnosis and report cites logs, documents, issues, or pull requests. | Q&A "Why the Planner comes first?" |
| NFR-10 | Errors: `main` waits on an error channel. It is closed unused on success. It carries all error messages on failure. | §Implementation Styles |

## 8. Constraints and Assumptions

- vcpkg tool 2026-09-26. Its locks cover `installed/`, `buildtrees/`, and `packages/`, and `x-add-version` hashes the working tree (Research §2).
- Copilot CLI 1.0.114 speaks SDK protocol 4. The team needs `github.com/microsoft/copilot-sdk/go/v2` (v2.0.4 or newer). The draft's `github.com/github/copilot-sdk/go` v1.0.28 speaks protocol 3 and fails at start (Research §5.1).
- The shared-session mechanism (`Agent.Select` with per-member tool allowlists, compaction that keeps the selection and the shared history) was verified live (Research §5.1). `Agent.Select` is still marked experimental.
- Go 1.26 or newer (`go.mod`; required by Copilot SDK Go v2.0.4).
- `gh` is authenticated. Without network access, the Port Doctor and Port Editor degrade to local evidence.
- Single model per run (Ideation).

## 9. Gaps and Gap-fills

| ID | Gap in the ideation | Proposed fill | Status |
|----|---------------------|---------------|--------|
| G-1 | Update requests (US-2, US-3) have no channel from the Planner to the Port Editor. | Options: (a) Planner to Port Doctor, which sends `PortGoals` to the Port Editor; (b) Planner to Port Editor; (c) Planner to Port Installer with reason "update", then Port Doctor. Recommended: (a). Not adopted: it changes the architecture. | Open, critical, needs user decision |
| G-2 | The Triplet Editor is defined twice. | One member with both duties. | Doc fix |
| G-3 | The Q&A title "Environment Detector and Port Editor" likely means the Planner. | Rename the question. | Doc fix |
| G-4 | The serial rationale cites a lock in `VCPKG_ROOT`. vcpkg 2026-09-26 locks `installed/`, `buildtrees/`, and `packages/`. | Keep serial work (shared session). Update the rationale. | Doc fix |
| G-5 | Detection rule and hybrid workspaces (a registry root with a manifest in a subfolder). | vcpkg's own manifest discovery from the working directory decides. Registry needs `ports/` and `versions/`. | Gap-fill |
| G-6 | How the "user instruction" for write access reaches the team. | CLI flags in `init`; the prompt narrows only. | Gap-fill, pending |
| G-7 | Manifest install request and the owner of `vcpkg.json` edits. | `triplet + features[]`; Port Editor owns manifest edits. | Gap-fill, pending |
| G-8 | Doctor routing in the manifest scenario conflicts with "CAN EDIT overlay folders". | Route by write permission of the fix target. | Gap-fill, pending |
| G-9 | `.clean` is re-extracted on every build; the Port Editor writes only the port folder. | Scratch copy, diff into a new patch, delete the scratch. Feasibility verified (Research §8.9). | Gap-fill, pending |
| G-10 | No limits on the port cycle and the triplet path. | 3 cycles per port; 1 edit per triplet per run; ledger. | Gap-fill, pending |
| G-11 | "Stacks" requests: last-in-first-out or arrival order? | Arrival order; retries first. | Gap-fill |
| G-12 | `vcpkg remove` before install in manifest mode. | Not used; vcpkg rejects it and reconciles (Research §8.4). | Gap-fill, verified |
| G-13 | Secret handling is not addressed. | Never log or send values; redact model-visible output. | Gap-fill |
| G-14 | "Actual permission check" versus "NOT for write access". exFAT has no ACLs to query. | Create and delete one uniquely named probe file, only in folders the team plans to write and in the vcpkg roots; report read access elsewhere. | Gap-fill, pending |
| G-15 | Definition of "latest stable commit". | The newest commit on the port's `HEAD_REF` branch (the default branch when absent) whose GitHub checks passed. | Gap-fill, pending |
| G-16 | Commit order "based on the recent changes". | Dependencies first, then the team's change order. | Gap-fill, pending |
| G-17 | Meaning of "Embed the tips in the current repository". | Follow the repository's guides and patch conventions, and add a short "why" header to each new patch. | Gap-fill, pending |
| G-18 | May the team install system packages? | Search only; installing is the user's action. | Gap-fill |
| G-19 | Lock held by another vcpkg process. vcpkg fails after about 1.5 s; `--x-wait-for-lock` waits (Research §8.3). | Pass `--x-wait-for-lock`; Go enforces a wait budget (default 10 minutes), then the Port Installer reports a blocker with the lock path. | Gap-fill, pending |
| G-20 | Explicit scenario switch. | Undecided in the ideation. | Open, low |
| G-21 | `--overwrite-version` in version updates. The registry's own script always passes it. | Only for versions not yet on the base branch, as upstream does (Research §6.11). Otherwise a forgotten `port-version` bump fails loudly. | Gap-fill, pending |
| G-22 | User interaction during a run. | None: runs are non-interactive; CLI flags set permissions; blockers go into the final report. | Gap-fill, pending |
| G-23 | Final report format and location. | Open: stdout only, or also a file. | Open, low |
| G-24 | Resume after a crash during a long run. | No resume in v1: rerun; binary caching makes finished ports cheap (Research §8.1). `ResumeSession` can interrupt a running tool call (Research §5.2). | Gap-fill, pending |
| G-25 | Remote writes: push, pull requests, issues. The ideation names only local commits. | None; commits stay local. | Gap-fill |
| G-26 | Install mode in the registry scenario ("Mostly we won't use classic mode, but we need to know for this case"). | Classic mode with explicit overlays, matching the Port Installer's commands. Not a test manifest. | Gap-fill, pending |

## 10. Open Questions

Grilling rounds settle these in priority order.

| Round | Questions | Outcome |
|-------|-----------|---------|
| 2 | G-6 to G-10 | User unavailable. Recommendations recorded as pending gap-fills. |
| 3 | G-1, G-26, G-19, G-16, G-17 | User unavailable. G-26, G-19, G-16, G-17 recorded as pending gap-fills. G-1 stays open: it changes the architecture. |
| 4 | G-1, G-14, G-15, G-22, G-24 | User unavailable. G-14, G-15, G-22, G-24 recorded as pending gap-fills. G-1 still open. |
| Next | G-1 (decision), confirmation of all pending gap-fills, then G-20, G-23 | Pending |

## 11. Traceability

| Story | Members involved | Key requirements |
|-------|------------------|------------------|
| US-1 | Planner, Environment Detector, Port Installer, Port Doctor | FR-P-2, FR-E-1..4, FR-I-4, FR-D-5 |
| US-2 | All seven | FR-P-9, FR-PE-2..5, FR-I-3..8, FR-TE-4..6, FR-B-1..4 |
| US-3 | Planner, Port Editor, Port Installer, Port Doctor, Baseline Updater | FR-P-9, FR-PE-3, FR-PE-5, FR-B-2 |
| US-4 | Port Doctor, Port Editor, Port Installer, Baseline Updater | FR-D-6, FR-PE-4, FR-B-3 |
| US-5 | Planner, Environment Detector, Port Installer, Port Doctor, Port Editor | FR-E-7, FR-D-5, FR-PE-9 |
| US-6 | Planner, Environment Detector, Port Installer, Port Doctor | FR-E-3, FR-E-11, FR-D-1..4 |
| US-7 | Port Doctor, Triplet Editor, Environment Detector, Planner, Port Installer | FR-TE-1..6, FR-E-9, FR-I-11 |
| US-8 | Environment Detector, Planner, Port Installer | FR-E-3, FR-E-6, FR-T-11, NFR-1 |

## 12. Scenario Evidence and Acceptance Fixtures

The ideation calls the user stories "ideas to test vcpkg team". This table links each scenario to local evidence and to a fixture that an acceptance test of the team can reuse. Fixtures are defined in Research §8.

| Scenario | Evidence (Research) | Fixture for team tests | Expected team result |
|----------|---------------------|------------------------|----------------------|
| US-1.1 | P-4 (0.12 s classic dry run) | Registry overlays, any known ports | Plan per triplet, no build, no file change |
| US-1.2 | P-6 (29 s manifest dry run) | A manifest in a subfolder | Plan without port arguments; note on `buildtrees` writes |
| US-1.3 | P-8 (`does not exist`, exit 1) | Unknown port name | Blocker with closest names |
| US-1.4 | L5 (dry run passes; install fails at compiler detection) | `agent-probe-ok:arm64-osx` on Windows | Blocker at `--only-downloads` |
| US-2.2 | L2 (`BUILD_FAILED`, `error-logs`, `issue_body.md`) | `agent-probe-fail` | `InstallFailure` with log paths; port cycle runs |
| US-5.2, US-5.4 | L4 (manifest rebuilds a changed overlay port) | Scratch manifest with overlay ports | Port Editor change, then automatic rebuild |
| US-8.4 | L3 (`failed to take lock` after 1.5 s; `--x-wait-for-lock` waits) | `agent-probe-sleep` holding the locks | Wait within budget, then blocker (G-19) |
| US-8.5 | L6i (`Invalid triplet name`) | Blank `VCPKG_DEFAULT_TRIPLET` | Blocker naming the variable |
| US-8.6 | L12 (`dubious ownership` on exFAT; CRLF tree mismatch; format check failure) | This repository on `D:` (exFAT, CRLF) | Blocker before installs; Baseline Updater step not attempted |
| FR-E-7 | L7 (`#COMPILER_*` lines in 2 s) | Any triplet | Compiler facts in `EnvReport` |
| FR-PE-3 | L10 (byte-exact patch applies with vcpkg's command) | `zlib-ng` `.clean` copy | Patch in the port folder; no stray files |
| FR-T-2, FR-T-3 | Research §5.1 (SDK live probe: `Agent.Select` enforces tool allowlists; compaction keeps the selection and the shared history) | Two members with disjoint tools | Each member calls only its tools; the next member recalls earlier results after compaction |

Scenarios without local evidence (US-2.1, US-2.4, US-3, US-4, US-6, US-7) need network access, other hosts, or real upstream changes. They remain design-level until the team exists.

Implementation coverage in `vcpkg-agents_test.go` now exercises the local registry dry run (including the compiled CLI and one live shared SDK session), manifest dry run, unknown port, unsupported target, real install/remove, patch generation, two local baseline commits, version-record tree guards, environment blockers, hooks, and all member definitions. No mock, fake, or stub is used. A full Doctor/Editor repair and Triplet Editor reinstall remain live-fixture tests rather than verified implementation acceptance.
