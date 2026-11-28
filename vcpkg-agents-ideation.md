# Ideation for Vcpkg Agent Team with Copilot SDK

[Single source](./vcpkg-agents.go), Copilot SDK based vcpkg request handler team.

## Tools

- Shell: Prefer native and latest shells. Bash, Zsh, PowerShell, etc.
- GitHub CLI: search, fetch repositories and files in GitHub (or GitHub Enterprise)
- vcpkg: https://github.com/microsoft/vcpkg-tool
  - vcpkg expects some system level tools.
  - https://github.com/microsoft/vcpkg/blob/master/scripts/bootstrap.sh
  - https://github.com/microsoft/vcpkg/blob/master/scripts/bootstrap.ps1
- CMake, Ninja, Meson, MSYS tools, etc.: Prefer system installed executables, but vcpkg downloads them automatically it if they are NOT available.
- Git or other version control system tools: We expect `git` by default, but other VCS are still in support coverage.

### Concerns

Some vcpkg selected tools for more complicated works. We don't need to know all of them, but they're in concern when we encounter some failures.

- https://github.com/microsoft/vcpkg/blob/master/scripts/cmake/vcpkg_find_acquire_program.cmake
- https://github.com/microsoft/vcpkg/tree/master/scripts/cmake
- https://github.com/microsoft/vcpkg/tree/master/ports/vcpkg-cmake

## Workspace Scenarios

We have 2 types where we run vcpkg executables and the agent team.
We're considering explicit switch for the scenarios. But not decided yet. Automatic detection is preferred, with logging.

### vcpkg [registry](https://learn.microsoft.com/en-us/vcpkg/concepts/registries) scenario

Reference vcpkg [classic mode](https://learn.microsoft.com/en-us/vcpkg/concepts/classic-mode) and overlay options. Mostly we won't use classic mode, but we need to know for this case.

- Folder organization layout follows the vcpkg upstream or vcpkg-registry: `ports`, [`versions`](https://learn.microsoft.com/en-us/vcpkg/users/versioning.concepts), [`triplets`](https://learn.microsoft.com/en-us/vcpkg/concepts/triplets), etc.
  - Some overlay options([`--overlay-ports`](https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports), [`--overlay-triplets`](https://learn.microsoft.com/en-us/vcpkg/commands/common-options#overlay-triplets), `VCPKG_OVERLAY_PORTS`, `VCPKG_OVERLAY_TRIPLETS` ) [need to be explicit](https://learn.microsoft.com/en-us/vcpkg/commands/common-options).
  - https://devblogs.microsoft.com/cppblog/registries-bring-your-own-libraries-to-vcpkg/
  - https://github.com/topics/vcpkg-registry
- Probably in port development or maintenance.
- Probably working for microsoft/vcpkg contribution, or self-maintained vcpkg-registry.

### vcpkg manifest scenario

Reference the official vcpkg [manifest mode](https://learn.microsoft.com/en-us/vcpkg/concepts/manifest-mode) document. The team is NOT working in vcpkg registry.

- The workspace folder contains [vcpkg.json](https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json), [vcpkg-configuration.json](https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json)
  - Sometimes the team may need to consider the [`--x-feature` option](https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-json#features).
  - [`--x-manifest-root` option](https://learn.microsoft.com/en-us/vcpkg/commands/common-options#manifest-root) can be used if vcpkg.json are NOT located in repo root.
- The team CAN EDIT the vcpkg.json and vcpkg-configuration.json file. To make successful package installations.
- The tema READs existing documents, GitHub Actions workflows, CMake related files(CMakeSettings.json, CMakePresets.json, CMakeLists.txt, *.cmake files, etc.), and some other build system files that actually consumes vcpkg installed artifacts.
- The team CAN EDIT overlay ports folder and overlay triplet folder, if they exists.
- The agent team MAY create local `ports/` folder and `triplets/` folder, if user explicitly allowed to do so.
- Probably in repository CI maintenance. Less related to vcpkg itself.
- Updating vcpkg dependencies based on [Dependabot report](https://learn.microsoft.com/en-us/vcpkg/concepts/dependabot).

## Agent Team Members

- Each member can run `vcpkg help`(`vcpkg help <topics>`, `vcpkg help <commands>`, etc) To correct their wrong argument usage with `vcpkg` tool.
- Each member communicates through Go channel. We follow CSP(Communicating Sequential Process) principles.
- Only specified members can edit(write access) files via given tools. Mostly read-only and execute the tools safely.

### Definitions

We have multiple team members, but all of them share the single Copilot session.
We can't work in parallel because the core task is `vcpkg install`, which uses file lock in `VCPKG_ROOT` that forbits parallel installation in single vcpkg root.

#### Planner

- Planner decides(judges) whether the task has finished, or blocked.
- Delegate the scenario, availability detection to the Environment Detector.
- Decides the installation sequence from the detection results.
- Installation can be blocked because of various reasons: SDK/Toolchain unavailable, Unknown system name, etc.

#### Environment Detector

- Locate the buildtrees, packages, [installed](https://learn.microsoft.com/en-us/vcpkg/reference/installation-tree-layout), caches, etc.
  - When they're designated, `--x-buildtrees-root`, `--x-packages-root
- Locate where the ports exists. If unknown, follow the vcpkg defaults.
- Locate where the triplets exists. vcpkg upstream's official triplets, commuinity triplets, and the overlay triplets.
- If [related environment variables](https://learn.microsoft.com/en-us/vcpkg/users/config-environment) are set, verify they're ready and permitted: `VCPKG_DOWNLOADS`, `VCPKG_DEFAULT_BINARY_CACHE`, `VCPKG_VISUAL_STUDIO_PATH`, etc.
- Invoke tools. The tools' command are NOT for write access. Simple version identification, path acquisition, and actual permission check.
- Several famous package manager(`apt`, `winget`, Chocolatey, Homebrew, etc.) search allowed. This is to notify Planner that the system can search and install the required tools from the package managers.

#### Triplet Editor

- Read the in-use triplet files
- Fetch and read the vcpkg official documents
- Consider fixes can be used to resolve installation error.
- Evaluate how those fix candidates can affect installing ports.

#### Port Installer

- Design install commands from Planner forwarderd `triplet + ports[]`.
- `vcpkg list` which ports are installed.
- Explicit `vcpkg remove` before install
- `vcpkg install --triplet=<triplet> <ports>` to detect failure early. Note the argument order may different.
  - Try [`--dry-run` option](https://learn.microsoft.com/en-us/vcpkg/commands/install#dry-run) to ensure all ports are known and available.
  - Try [`--only-downloads` option](https://learn.microsoft.com/en-us/vcpkg/commands/install#--only-downloads) to acquire tools in advance.
- Batch `vcpkg install --triplet=<triplet> <ports>` of ports in foreground. Caution: This may take hours.
  - We won't read the terminal output because they can be humongeous.
  - Use the vcpkg created log files instead: For example, `Get-ChildItem ${env:VCPKG_ROOT}\buildtrees\*\stdout-x64-windows.log` in PowerShell 7+
- Stacks the received install request. When all installations are succeeded, report the Planner that they're finished.
- When installation failed, forward the session to doctor. States the `vcpkg install` reported files with buildtree path.

Constraints
- Read access on folders. Intermediate files are only from the tool invocation. No direct file creation.

#### Port Doctor

- Diagnose configure, build, install failure
  - Reference official troubleshooting guides. https://learn.microsoft.com/en-us/vcpkg/troubleshoot/build-failures https://learn.microsoft.com/en-us/vcpkg/users/versioning-troubleshooting
  - [Binary Caching](https://learn.microsoft.com/en-us/vcpkg/users/binarycaching-troubleshooting) issues are not error, but warning.
  - Search the reported [issues](https://github.com/microsoft/vcpkg/issues), [discussions](https://github.com/microsoft/vcpkg/discussions), [pull requests](https://github.com/microsoft/vcpkg/pulls) that already addressed the failure.
- Perform research in multiple axis: Build configuration, Toolchain, Installation, etc.
- If manifest scenario, report the failure to Planner directly.
- If registry scenario, forward the diagnosis to Port Editor. So the agent can edit the failed ports. The team continues cooperation.
- Scan buildtree files, to diagnose that the target port needs additional port dependency. Sometimes another port need to be created.
  - Hard copy from microsoft/vcpkg upstream ports
  - Additional installation patches to fix `find_package` or `pkg-config` errors.
  - Nested, embedded source files(CMake `add_subdirectory`) to vcpkg ecosystem friendly port(`find_package`).

Constraints
- Read access to local files
- Web search to gather informations
- (optional) MCP tools for read access on enterprise environment: Slack, Confluence, GitHub Enterprise, etc.

#### Port Editor

The agent can read the other ports' files for references.

- portfile.cmake, vcpkg.json manifest editor
- Patch creation. Embed the tips in the current repository.
- New port creation with `vcpkg create` command. Portfile edit followed to enhance from the template.
  - Web search allowed. To acquire project details, releases, source archives, and buildsystem it uses.

#### Triplet Editor

- Based on the Doctor's diagnosis, create/edit the triplet file and make the next tasks use it.

#### Baseline Updater

- Reference registry-format.ps1, registry-add-version.ps1 and related vcpkg commands
- Create 2 commits per port: format the port files, commit the changes, and append version baseline update commit.
- Breakdown port commit order based on the recent chagnes.

### Relationships

The start: User -> Planner.

#### Planner <-> Environment Detector

- Both share the same sesion
- In given condition, detect host system and target system information. vcpkg `detect_compiler` and some other utilities.
- Detector estimate which triplets will be used in the team's plan.
- Detector Report which environment variables exists, where the tools are available, what folders are readable/writable, and whether the team can access web resources (to search known port issues later in Doctor)
- Not only PATH tests. Run the tools to get their absolute paths and versions.

#### Planner -> Port Installer

- Transmit multiple `triplet + ports[]` in sequence. For example, the planner will request (`arm64-windows` triplet + several ports), then (`arm64-android` triplet + several ports) based on the user instructions.
- Port install runs the proper `vcpkg install` command with given triplet and ports.

#### Port Installer -> Planner

- When installations were successful, there are nothing to do but report to user. Let the Planner decide next action.

#### Planner <-> Baseline Updater

This is for registry scenario, not for manifest scenario.

- Given registry scenario, when ports' installation were all good, then we need to create commits for the registry's `ports/` and `versions/`.
- Multiple port changes will be breakdown into separated commits. By doing so each commit can be `git cherry-pick`ed to other Git branch whenever helpful.
- When all ports' baseline are changed properly, the session handoffed to Planner.

#### Port Installer -> Port Doctor

- Diagnose the failure hints from `vcpkg install` command.
  - Build configuration: CMake, Meson, UNIX Makefile, Ninja, etc.
  - Toolchain: Compiler or Linker error
  - Installation: vcpkg warnings against wrong package layout, Build system integration mismatch, etc.
  - Misc: Unknown category that agent need to search known issues and fix on their own.
- Port Doctor performs actual research and gather evidences. Very strategic approach. It utilizes available tools to search the known references and various web resources.
  - Generate diagnosis of the install failure
  - Define goals for the port changes. The state that Port Installer can start its work with confidence.

#### Port Doctor -> Port Editor

- Doctor transmit the goals against a single port, and diagnosis for multiple ports (mostly same single port, related to the goals)
- Port Editor generates patches from the current buildtrees, and change the files in target port folder.
- Port Editor updates [the version, port-version in vcpkg.json file](https://learn.microsoft.com/en-us/vcpkg/users/versioning). Leave the values if they already edited.
- Port Editor changes portfile.cmake and others. But it can only write the files in target port folder.

#### Port Doctor -> Triplet Editor

- Some errors may require the triplet changes. There are some known vcpkg variables.
- Doctor will transmit the target triplet file, [variables](https://learn.microsoft.com/en-us/vcpkg/users/triplets), and guidance to the Triplet Editor. For example, (`x64-osx.cmake` + "min SDK 12.0 required in macOS build").
- Triplet Editor will resolve what vcpkg variables and tool options need to be changed. Actually edit them properly.

#### Port Doctor -> Planner

- Report blockers that can't solve the error: The user is trying to install `arm64-osx` triplet on Windows OS. vcpkg will report that is NOT supported.

#### Port Editor -> Port Installer

- Because a port's files are changed, the team can try installation again.

#### Port Installer -> Port Installer

- When the port installation was success, resume the stacked, next installation.

#### Port Installer -> Planner

- Requested port install are finished.
- Or some failure that can't be resolved by Port Doctor and Port Editor.

#### Triplet Editor -> Planner

- When the message arrives from the Doctor, fix the triplet files.
  - Because the triplet has changed, we knows that vcpkg cache has invalidated (Read the document!).
  - Request to Planner for batch installation. The Planner will forward to Port Installer again, then Installer will cleanup the installed packages by its design.
- Planner will schedule the ports' installation again, just like when the message has arrived from the user.

#### Triplet Editor <-> Environment Detector

- Triplet edit may consider both host/target systems. If we need more detail against host system, to handle [host dependency](https://learn.microsoft.com/en-us/vcpkg/users/host-dependencies) failures, the Triplet Editor MAY need to rely on Environment Detector.


## Implementation Styles

- `init` function performs basic path acquisition, search known tools, detect environment variables, and parse CLI arguments. Global variables are set in advance to reduce burden of agents.
- `main` function creates channels and goroutines. Perform orchestration and wait on error channel. The error channel will be closed without use if successful, and multiple error messages if something went wrong.

## Concerns

- We need more trials and verifications to derive well-design failure paths.

### Design Policy

- We address single port in time. KISS the task and problem while installation. The port cycle(Installer -> Doctor -> Editor) is designed for it.
  - Clean role separation/delegation to enforce sequantial analysis and handling, harmonied loop of agents for retry. 
  - The cycle naturally break down the multiple port installations. When Port Installer receives port array through the channel, it tries to install all of them. But when a port fails, the port and its details will be transmitted to the Port Doctor.
- User instruction decides whether read-only or writable access on the folders. Each workspace has default values.
  - In manifest scenario: Mostly read-only. Installation failure will be reported to user.
  - In registry scenario: we assume we're in maintenance of ports and triplets. We can edit the known port folders and triplet folders. Our goal is to make them work, especially for user selected ports in given target system(triplet in other words).
- Vcpkg's cachcing implicitly helps the team. If there are existing binary cache, Port Installer will save its time. We never think caching itself is unnecessary and noise. Therefore, we limit the use of `--editable` while `vcpkg install`. Port Doctor will work directly on the `*.clean` folder in the `buildtrees/`.

### Questions

Q. Why we separate Environment Detector and Port Editor?
A. Environment check can be deterministic. If so, we can perform the steps in advance. Later agents will need tool that performs the exactly same procedure, but direct detection process and immediate troubleshooting will help later agents through the session memory.

Q. Why the Planner comes first? and why it doesn't have write access?
A. Even though the agent is an entry point, it delegates most of work to minimize session context usage. Plan can be fragile, however, the CSP design backed delegation can be more robust. We don't use plan because it requires a kind of assumptions. In our design, the team actually invokes to the tools, then moves with clear evidences. Each agent's messages are about goals. The messages won't be concrete instructions and steps. That strategy will keep the members advance with the goals and delegate when it finished its role.

Q. Why CSP, not subroutines?
A. Easy to design, Easy to expand. We follow the Go language philosophy. And it will help future maintenance of the team. Separate the concerns of team design from the available tasks.

Q. Context compaction?
A. The agent team will share a single session. They handoff the session identity while messaging (And an agent member takes their own turn, by design). This is because we can't run vcpkg executable in parallel. But horizontal session may consume large context, so we must run compact before we send messages via channel. And we expect the team to use single model. So compaction can be reused automatically by the Copilot.

## User Stories

Several ideas to test vcpkg team.

### Simple Dry Run

### Batch Port Update

### Make a Port to use the latest Stable commit

### Port Creation (Requested from other port installation)

## References

Use the references of the repository documents.
