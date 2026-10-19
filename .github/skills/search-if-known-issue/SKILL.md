---
name: search-if-known-issue
description: Investigate vcpkg port build or install failures by checking the current build environment and target system, then searching GitHub issues and PRs for matching reports or fixes. Use when a port fails to configure, compile, link, or install, before developing a local fix or patch.
---

# Search If Known Issue

Determine whether a port failure matches an existing GitHub report or fix before developing a local patch.

## Goals

- PASS: Environment and failure evidence captured, relevant repositories searched, and an actionable handoff provided.
- BLOCKED: Required evidence or GitHub access is unavailable; report the gap and the next action.
- A completed search with no applicable match is a valid result, not proof that the issue has never been reported.

## User Input

Accept a failed installation command, port specification, error excerpt, or build log path.
Reuse evidence from the current conversation and installation attempt. Ask only for information that remains blocking.

## Process

### Phase 1: Capture the Failure

1. Record the exact command, exit code, requested port, features, target triplet, and host triplet.
2. Identify the package that actually failed, including transitive or host dependencies.
3. Read its resolved manifest, portfile, and patches. Record version, port-version, source REF/commit,
   registry baseline, overlay paths, and local modifications relevant to the failure.
4. Read the log paths printed by vcpkg. Use the configured buildtrees root rather than assuming a default.
   Extract the first causal diagnostic and a short surrounding excerpt, not just `BUILD_FAILED`.
5. Classify the failure as download, configure, compile, link, install, post-build validation, or environment.
   Preserve logs and existing work; reproducing or cleaning the build is not a prerequisite for searching.

### Phase 2: Check Host and Target Information

1. Invoke `check-environment` for current host OS/version, architecture, shell, vcpkg executable/version,
   and tool availability. Reuse a current report if it describes the same build environment.
2. Distinguish the machine running this investigation from the machine/container/CI runner that produced the logs.
   For a remote failure, use that runner's evidence; local inspection alone does not establish its environment.
3. Read the effective target and host triplet files, chainloaded toolchain, and relevant build configuration.
   Record target OS, architecture, static/shared linkage, CRT linkage, and cross-compilation settings.
4. Capture the compiler, linker, CMake, generator/build tool, and SDK versions actually selected in the failing
   logs or CMake cache. PATH versions alone may differ from tools selected or downloaded by vcpkg.
5. Capture platform-specific details when relevant: Visual Studio toolset and Windows SDK, CUDA toolkit,
   Android NDK/API/ABI, Apple SDK/deployment target, or Linux distribution/libc/sysroot.
6. Mark each unverified detail as unknown. Ask for missing details if they prevent evaluating a candidate match.
   Keep credentials, private paths, hostnames, and sensitive environment values out of search queries and reports.

### Phase 3: Search GitHub Issues and PRs

1. Determine repositories from evidence:
   - `microsoft/vcpkg` for port packaging, toolchain integration, and build regressions.
   - The source project's repository from its portfile/homepage for upstream code or build-system failures.
   - This registry for local overlays; dependency/tool repositories when the diagnostic points there.
   - `microsoft/vcpkg-tool` when the failure points to the vcpkg executable itself.
2. Prefer `gh` commands in the current platform's shell. Search issues and PRs separately, covering open and
   closed states, including merged PRs. Avoid state filters on the initial search.
3. Start with the failed package name and a distinctive diagnostic fragment or symbol. Then vary the query:
   - Package name plus compiler/toolchain, target OS/architecture, or affected version.
   - Shorter diagnostic fragments without machine-specific paths, line numbers, or generated identifiers.
   - Upstream project name or dependency name where it differs from the port name.
4. Example PowerShell commands; substitute verified repository names and sanitized search terms:
   ```powershell
   gh search issues '"diagnostic fragment" port-name' --repo microsoft/vcpkg --limit 30 --json number,title,url,state,updatedAt
   gh search prs '"diagnostic fragment" port-name' --repo microsoft/vcpkg --limit 30 --json number,title,url,state,updatedAt
   gh issue view <number> --repo <owner/repo> --comments
   gh pr view <number> --repo <owner/repo> --comments
   gh pr diff <number> --repo <owner/repo>
   ```
5. Record repositories, queries, search time, and result limits. When a limit is reached, narrow the query or
   retrieve further results before concluding that no applicable match was found.
6. Treat authentication, network, and rate-limit errors as blocked searches, not empty results.
   Use another available GitHub access method if possible; disclose any remaining coverage gap.
   Search with sanitized public terms only; keep full logs and local source private.

### Phase 4: Verify Candidate Matches

1. Read candidate issue/PR bodies, relevant comments, linked duplicates, and fix diffs rather than relying on titles.
2. Compare the causal diagnostic, affected code, package version, compiler/SDK, features, and host/target combination.
   State matching evidence and meaningful differences; classify candidates as confirmed, likely, or unrelated.
3. Verify whether a proposed fix is open, merged, reverted, or included in a release/port revision.
   A closed issue alone does not establish resolution, and a merged PR may not be in the installed version.
4. Check whether the local port already contains the fix. Treat a persisting failure as a possible regression or
   different cause, rather than recommending the same patch again.

### Phase 5: Handoff

- **Applicable fix found:** Cite the issue/PR and exact fix commit or released version. Explain applicability and
  hand off to the smallest supported remedy: environment correction, port update, or verified patch backport.
  Use `update-port` when a version update is the selected remedy.
- **Known issue, unresolved:** Cite the report, summarize its current status, and identify any verified workaround.
  Hand off to local diagnosis if it still requires a fix, carrying forward the known evidence.
- **No applicable match after completed searches:** Continue with your own root-cause investigation and focused
  fix/patch within the user's authorized scope. Carry forward the reproduction command, logs, environment,
  excluded candidates, and a testable hypothesis. Do not stop at "nothing found."
- **Search or evidence blocked:** Report what remains unknown and obtain the missing evidence/access before
  claiming a completed search.

For a local fix, preserve unrelated changes, modify only the affected port/build configuration, and verify with
`install-port` using the original features and host/target configuration. Then use `review-port` for port changes.
If verification fails, compare the new causal diagnostic and continue diagnosis; repeat the search only when new
evidence changes the query. Report the fix as verified only after the relevant build/install succeeds.
Create issues, PRs, or commits only when requested.

## Reporting

Return a concise report with these headings:

1. `# Known Issue Search Report`
2. `## Summary` — Port/version, timestamp, and outcome: FIX FOUND / KNOWN UNRESOLVED / NO MATCH / BLOCKED.
3. `## Failure Evidence` — Command, failing dependency, stage, causal excerpt, and log paths.
4. `## Host and Target` — Observed environment, effective triplets/tools/SDKs, and unknown details.
5. `## Search Coverage` — Repositories, queries, limits, and access gaps.
6. `## Matches` — Table of issue/PR links, status, applicability/confidence, and fix commit/release if verified.
7. `## Handoff` — Chosen remedy or local investigation, affected files, reproduction, and validation result/pending check.

Use ✅ for verified evidence or an applicable fix, ⚠️ for uncertainty/no applicable match, and ❌ for a blocking gap.
Use fully qualified `owner/repo#number` references for repositories other than this registry.
When displaying GitHub search results, use `show-github-search-result` if available.

## References

- [Troubleshooting guide](../../../docs/troubleshooting.md)
- [Environment checks](../check-environment/SKILL.md)
- [Installation and log analysis](../install-port/SKILL.md)
- [Port review](../review-port/SKILL.md)
