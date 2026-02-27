# Plan: Converting Copilot Prompt Files to Agent Skills

Conversion plan for migrating this repository's GitHub Copilot prompt files to the Agent Skills format.
This document serves as the primary reference for planning and milestone tracking.

> **Focus:** Design, analysis, and milestone planning only. Existing prompt files are preserved as-is.

## 1. Background and Motivation

### 1.1 Current State

This repository uses eight GitHub Copilot **prompt files** (`.github/prompts/*.prompt.md`) to assist maintainers with vcpkg port management tasks:

| Prompt | Task | Trigger |
|--------|------|---------|
| `/check-environment` | OS/shell/vcpkg validation | Manual invocation |
| `/search-port` | Find ports locally or upstream | Manual invocation |
| `/create-port` | Generate new port files | Manual invocation |
| `/install-port` | Run vcpkg install and analyze logs | Manual invocation |
| `/review-port` | Validate port files against guidelines | Manual invocation |
| `/check-port-upstream` | Check for newer upstream versions | Manual invocation |
| `/update-port` | Bump version, SHA512, test | Manual invocation |
| `/update-version-baseline` | Sync `versions/` baseline files | Manual invocation |

All prompts must be **explicitly invoked** by the maintainer using the `/command` syntax inside Copilot Chat. The Copilot Coding Agent has no automatic awareness of these workflows when operating autonomously (e.g., when assigned to a GitHub Issue or Pull Request).

### 1.2 What Are Agent Skills?

GitHub Copilot **Agent Skills** (announced December 2025) are a newer mechanism for encoding institutional knowledge as portable, self-contained packages that AI coding agents can **auto-discover and apply**:

```
.github/skills/
  <skill-name>/
    SKILL.md        ← required: frontmatter + instructions
    [scripts/]      ← optional: helper scripts, templates
    [resources/]    ← optional: reference files
```

Each `SKILL.md` has a minimal structure:

```markdown
---
name: skill-name
description: When and why to use this skill. Trigger phrases for activation.
---

# Skill Instructions

Step-by-step workflow with rules, examples, and references.
```

Skills are consumed by the **Copilot Coding Agent** when it autonomously processes GitHub Issues and Pull Requests, and by compatible tools such as Claude Code and OpenAI Codex via the open [agentskills.io](https://agentskills.io) standard.

### 1.3 Why Convert?

The primary motivation is to enable **autonomous agent-driven maintenance**. When a maintainer assigns a GitHub Issue labeled `port-request` to the Copilot Coding Agent, the agent should be able to:

1. Recognize the request as a port creation task (via skill description matching)
2. Load the relevant `create-port` skill automatically
3. Follow the encoded workflow without further instruction

This cannot be achieved with prompt files today, which require explicit human invocation.

---

## 2. Comparison: Prompts, Agents, and Skills

### 2.1 Feature Comparison

| Dimension | Prompt Files | Agent Skills | Custom Agents |
|-----------|-------------|--------------|---------------|
| **Location** | `.github/prompts/*.prompt.md` | `.github/skills/*/SKILL.md` | `.github/copilot/*.agent.md` |
| **Invocation** | User types `/command` | Auto-discovered by coding agent | User selects agent persona |
| **Persistence** | One-shot per invocation | Loaded per task automatically | Persistent session persona |
| **Tool spec** | In frontmatter (`tools:`) | Implicit (agent's own tools) | Specified per agent |
| **Model spec** | In frontmatter (`model:`) | Inherited from agent | Specified per agent |
| **Portability** | VS Code / GitHub Copilot Chat | Cross-tool (VS Code, Claude, Codex) | Copilot-specific |
| **Complexity** | Medium (multi-phase prompts) | Simple (SKILL.md + resources) | High (persona + tool config) |
| **Status** | GA (stable) | Experimental → GA (2025-2026) | GA (stable) |

### 2.2 Prompt Files — Pros and Cons

#### Pros
- **Mature and stable**: The `.prompt.md` format is well-documented and widely supported.
- **Explicit control**: Maintainer decides exactly when and in what context to invoke each workflow.
- **Rich tool configuration**: Frontmatter allows specifying `tools:`, `model:`, and `agent:` per workflow.
- **Structured reporting**: Multi-phase workflows with deterministic markdown output are easy to validate.
- **Familiar invocation**: Maintainers learn `/create-port` as a command, similar to IDE shortcuts.
- **Version-controllable**: Living alongside port files in the same repository.

#### Cons
- **Manual trigger required**: Every prompt requires explicit invocation — no automation.
- **No autonomous operation**: The Copilot Coding Agent (assignee on issues) cannot apply prompt workflows without being told.
- **Context loss**: Prompts do not persist knowledge between invocations; the maintainer must re-establish context each time.
- **Copilot-specific**: Prompt files use Copilot Chat; they do not carry over to Claude Code or other agents.
- **Tooling lock-in**: The `tools:` frontmatter uses Copilot-specific tool identifiers (e.g., `execute/runInTerminal`).
- **Discoverability**: New contributors must learn the `/command` syntax and which prompt to use when.

### 2.3 Agent Skills — Pros and Cons

#### Pros
- **Auto-discovery**: The Coding Agent loads relevant skills automatically based on description matching.
- **Autonomous operation**: When the Coding Agent is assigned to an issue, it applies skills without human prompting.
- **Cross-platform portability**: Compatible with the open `agentskills.io` standard (VS Code, Claude Code, Codex).
- **Composable**: Skills can reference each other and include shared helper scripts.
- **Lower cognitive load**: Contributors do not need to memorize command names — skills activate on context.
- **Richer resource support**: Can bundle shell scripts, PowerShell scripts, templates, and reference docs within the skill directory.

#### Cons
- **Still experimental** (as of early 2026): The format may evolve; VS Code Insider-only for some features.
- **Reduced control**: Auto-activation means the agent may apply a skill in unexpected contexts; requires precise descriptions.
- **Less explicit reporting**: Skills produce freeform agent output rather than the structured markdown reports that prompts define.
- **Setup overhead**: Each skill requires its own directory and `SKILL.md`; more files to maintain.
- **Weaker tool isolation**: Cannot restrict the agent to specific tool subsets per skill in the same way prompts do with `tools:` frontmatter.
- **Skill drift**: Since skills are always available, they may be invoked inappropriately if descriptions are too broad.

### 2.4 Custom Agents (`.agent.md`) — Pros and Cons

#### Pros
- **Role specialization**: Create a "Port Reviewer" agent distinct from a "Port Creator" agent.
- **Persistent context**: The agent maintains its persona and instructions throughout a session.
- **Precise tool access**: Can grant or restrict tools per agent (e.g., read-only access for reviewers).
- **Handoff support**: Agents can delegate subtasks to other agents.

#### Cons
- **Highest setup complexity**: Requires designing agent instructions, tool access, and interaction boundaries.
- **Overkill for task automation**: For port maintenance, the granularity of Custom Agents may exceed what is needed.
- **Limited portability**: Custom Agents are Copilot-specific; they do not translate to other AI coding tools.
- **Session-bound**: Requires maintainer to actively select the agent persona; not suitable for fully autonomous processing.

### 2.5 Recommended Strategy for This Repository

Given the repository's maintenance patterns (issue-driven port requests, version updates via PRs), the recommended approach is a **hybrid model**:

1. **Retain prompt files** for interactive, user-driven workflows (maintainer explicitly runs `/create-port`)
2. **Add skills** to enable the Copilot Coding Agent to autonomously handle GitHub Issues and PRs
3. **Optionally add custom agents** only if role specialization (e.g., security review vs. port creation) becomes necessary

This approach preserves existing workflows while adding autonomous capability on top.

---

## 3. Current Prompt Analysis

Each of the eight prompts is analyzed below for conversion readiness.

### 3.1 `/check-environment`

- **File**: `.github/prompts/check-environment.prompt.md`
- **Purpose**: Detect OS/shell, verify tools (curl, git, cmake, ninja), validate vcpkg installation and registry structure
- **Trigger**: Manual — run before starting any port work
- **Complexity**: Medium (4 phases, 13+ steps)
- **Conversion type**: **Diagnostic skill** — activated when the agent detects missing tools or an unvalidated environment
- **Key content to port**:
  - OS/shell detection logic
  - Tool version requirement thresholds (vcpkg ≥ 2025-06-20)
  - Registry folder validation (`ports/`, `versions/`, `triplets/`)
  - Environment variable inventory (`VCPKG_*`)
- **Scripts to bundle**: Bash/PowerShell version check fragments

### 3.2 `/search-port`

- **File**: `.github/prompts/search-port.prompt.md`
- **Purpose**: Find ports in local registry and upstream `microsoft/vcpkg` by name, URL, or keywords
- **Trigger**: Manual — before creating a new port or checking for duplicates
- **Complexity**: Medium (6 phases)
- **Conversion type**: **Lookup skill** — activated when agent receives a "does X port exist?" request
- **Key content to port**:
  - Local registry search logic
  - Upstream microsoft/vcpkg lookup strategy
  - Deprecation detection (empty package policy)
  - Version comparison format
- **Enhancement opportunity**: Add a canonical list of known alternative names (e.g., `openssl` → `openssl3`) as a bundled reference file

### 3.3 `/create-port`

- **File**: `.github/prompts/create-port.prompt.md`
- **Purpose**: Generate `portfile.cmake`, `vcpkg.json`, and optionally `usage` and patches from upstream project info
- **Trigger**: Manual — after confirming port does not exist
- **Complexity**: High (6 phases, 20+ steps)
- **Conversion type**: **Core workflow skill** — activated when agent is assigned a "port-request" issue
- **Key content to port**:
  - GitHub URL parsing and project metadata extraction
  - Build system detection (CMake vs. Meson vs. Autotools)
  - SHA512 download and calculation workflow
  - Port file templates (`vcpkg.json`, `portfile.cmake`, `usage`)
  - Validation checklist (SHA512 format, required fields)
- **Scripts to bundle**:
  - `scripts/registry-format.ps1` reference (already in repo)
  - SHA512 download snippets as reusable script fragments

### 3.4 `/install-port`

- **File**: `.github/prompts/install-port.prompt.md`
- **Purpose**: Execute `vcpkg install` with overlay-ports, analyze build logs, report success or failure
- **Trigger**: Manual — after port creation or update, before review
- **Complexity**: High (6 phases)
- **Conversion type**: **Validation skill** — activated when port files are newly created or modified in a PR
- **Key content to port**:
  - Overlay-ports command construction
  - Build log path patterns (`buildtrees/{port}/config-{triplet}-out.log`)
  - Error classification matrix (CMake, Compiler, Linker, Dependency, Platform)
  - Artifact verification checklist
- **Scripts to bundle**: Common install invocation templates as bash/PowerShell fragments

### 3.5 `/review-port`

- **File**: `.github/prompts/review-port.prompt.md`
- **Purpose**: Validate port files against vcpkg contribution guidelines; emit pass/fail report
- **Trigger**: Manual — before opening a PR or after installation test passes
- **Complexity**: High (7 phases)
- **Conversion type**: **Quality gate skill** — activated when a PR contains `ports/` changes
- **Key content to port**:
  - `vcpkg.json` validation rules (schema, version format, SPDX license)
  - `portfile.cmake` validation rules (helper functions, SHA512, copyright)
  - Deprecated function detection
  - Baseline cross-reference check
- **Reference files to bundle**: Link to `docs/review-checklist.md` as a bundled resource

### 3.6 `/check-port-upstream`

- **File**: `.github/prompts/check-port-upstream.prompt.md`
- **Purpose**: Compare local port version against upstream project and `microsoft/vcpkg`
- **Trigger**: Manual — during maintenance rounds or before updating a port
- **Complexity**: Medium (6 phases)
- **Conversion type**: **Monitoring skill** — activated by scheduled or manual "check for updates" tasks
- **Key content to port**:
  - Version normalization rules (strip `v`, project-name prefixes)
  - Upstream API query patterns (GitHub Releases API)
  - `microsoft/vcpkg` comparison logic
  - Breaking change keyword detection (`CVE`, `security`, `breaking`)
- **Enhancement opportunity**: Bundle a script that reads all `ports/*/vcpkg.json` to batch-check all ports at once

### 3.7 `/update-port`

- **File**: `.github/prompts/update-port.prompt.md`
- **Purpose**: Bump version/SHA512/REF in `vcpkg.json` and `portfile.cmake`, test with `--editable`
- **Trigger**: Manual — after confirming a newer version is available
- **Complexity**: High (8 phases)
- **Conversion type**: **Update workflow skill** — activated when agent is assigned a "port-update" issue or PR
- **Key content to port**:
  - Version normalization and REF pattern detection
  - SHA512 download and calculation workflow (shared with create-port)
  - Editable install test procedure
  - SHA512 mismatch correction loop
- **Scripts to bundle**: Version comparison and SHA512 calculation script fragments

### 3.8 `/update-version-baseline`

- **File**: `.github/prompts/update-version-baseline.prompt.md`
- **Purpose**: Run `registry-add-version.ps1` to update `versions/baseline.json` and per-port version files
- **Trigger**: Manual — after port files are committed and tested
- **Complexity**: Low (3 phases)
- **Conversion type**: **Registry sync skill** — activated when port commits are ready to be registered
- **Key content to port**:
  - Port name inference from git history and conversation context
  - `registry-add-version.ps1` invocation pattern
  - Git commit structure for version files
- **Scripts to bundle**: Reference to `scripts/registry-add-version.ps1` (already in repo)

---

## 4. Proposed Skill Structure

The target directory layout for all skills:

```
.github/
  skills/
    check-environment/
      SKILL.md
      resources/
        tool-checklist.md
    search-port/
      SKILL.md
      resources/
        known-aliases.md
    create-port/
      SKILL.md
      resources/
        portfile-template.cmake
        vcpkg-json-template.json
        sha512-calculation.md
    install-port/
      SKILL.md
      resources/
        error-patterns.md
    review-port/
      SKILL.md
      resources/
        review-checklist.md   ← symlink or copy of docs/review-checklist.md
    check-port-upstream/
      SKILL.md
      resources/
        version-normalization.md
    update-port/
      SKILL.md
      resources/
        sha512-calculation.md  ← shared with create-port
    update-version-baseline/
      SKILL.md
```

### 4.1 SKILL.md Frontmatter Template

All skills should follow this metadata structure:

```markdown
---
name: <skill-name>
description: >
  <One or two sentences explaining the skill's purpose and trigger conditions.
   Include the key phrases that should activate this skill automatically.>
license: MIT
---
```

### 4.2 Skill Description Design Principles

The `description` field drives automatic activation. It must be:

1. **Action-oriented**: Begin with a verb ("Validates", "Creates", "Updates")
2. **Trigger-rich**: Include phrases that appear in real issue/PR text ("port request", "install failed", "newer version")
3. **Scoped**: Describe boundaries ("for vcpkg ports in this registry only")
4. **Concise**: Under 200 characters preferred; loaded at every agent invocation

Example for `create-port`:
```
Creates a new vcpkg port from scratch. Use when asked to add a port, create a package, or handle a port-request issue. Covers source acquisition, SHA512 calculation, and file generation.
```

### 4.3 Shared Resources Strategy

Several prompts share overlapping logic (SHA512 calculation, version normalization). Instead of duplicating content:

- **Option A**: Place shared content in `.github/skills/_shared/` and reference from multiple `SKILL.md` files
- **Option B**: Place shared content in `docs/` and reference by path
- **Recommended**: Option B for now — the `docs/` folder already contains relevant guides and is better maintained

---

## 5. Conversion Milestones

### Milestone 1: Research and Baseline (Weeks 1–2)

**Goal**: Establish the baseline, validate the technology, and document decisions.

**Tasks**:
- [x] Audit all 8 existing prompt files (done — see Section 3)
- [x] Research Agent Skills format and tooling requirements (done — see Section 2)
- [ ] Create one pilot skill (`check-environment`) to validate the format in VS Code Insiders
- [ ] Validate auto-discovery behavior: does the skill activate on relevant prompts?
- [ ] Document findings in this file under a "Pilot Results" appendix

**Deliverables**:
- `.github/skills/check-environment/SKILL.md` (pilot)
- This planning document (updated with pilot results)

**Acceptance Criteria**:
- Copilot Coding Agent successfully loads and applies the `check-environment` skill autonomously
- Skill description triggers correctly on "check my environment" type requests
- No regressions to existing prompt files

---

### Milestone 2: Lookup and Discovery Skills (Weeks 3–4)

**Goal**: Convert the two information-retrieval prompts into skills.

**Prompts converted**:
- `/search-port` → `search-port` skill
- `/check-port-upstream` → `check-port-upstream` skill

**Tasks**:
- [ ] Write `search-port/SKILL.md` with local + upstream lookup instructions
- [ ] Bundle `search-port/resources/known-aliases.md` (port name alias list)
- [ ] Write `check-port-upstream/SKILL.md` with version comparison instructions
- [ ] Bundle `check-port-upstream/resources/version-normalization.md`
- [ ] Test: assign agent to "Is cpuinfo already in the registry?" issue
- [ ] Test: assign agent to "Check if openssl3 has updates" issue

**Acceptance Criteria**:
- Agent correctly identifies local vs. upstream ports without manual prompt invocation
- Version comparison normalizes semver and date-based formats correctly

---

### Milestone 3: Core Creation Skill (Weeks 5–7)

**Goal**: Convert the most complex prompt into a skill; this is the highest-value conversion.

**Prompts converted**:
- `/create-port` → `create-port` skill

**Tasks**:
- [ ] Write `create-port/SKILL.md` — condensed workflow from the 6-phase prompt
- [ ] Bundle `create-port/resources/portfile-template.cmake`
- [ ] Bundle `create-port/resources/vcpkg-json-template.json`
- [ ] Bundle `create-port/resources/sha512-calculation.md` (calculation procedure)
- [ ] Test: assign agent to a "port-request" issue for a simple CMake library
- [ ] Test: verify SHA512 calculation is accurate and the skill handles GitHub URL parsing
- [ ] Validate that the skill references `docs/guide-create-port.md` correctly

**Acceptance Criteria**:
- Agent generates a valid `vcpkg.json` and `portfile.cmake` when assigned to a port-request issue
- SHA512 is calculated correctly or a placeholder strategy is documented
- Port files pass `docs/review-checklist.md` checks

---

### Milestone 4: Installation and Review Skills (Weeks 8–9)

**Goal**: Convert the quality-assurance prompts into skills for PR-triggered automation.

**Prompts converted**:
- `/install-port` → `install-port` skill
- `/review-port` → `review-port` skill

**Tasks**:
- [ ] Write `install-port/SKILL.md` with overlay-ports install procedure
- [ ] Bundle `install-port/resources/error-patterns.md` (error classification rules)
- [ ] Write `review-port/SKILL.md` with validation checklist
- [ ] Symlink or copy `docs/review-checklist.md` into `review-port/resources/`
- [ ] Test: agent runs install and review when PR contains new port files
- [ ] Test: agent correctly classifies a CMake configuration error

**Acceptance Criteria**:
- Agent automatically runs review when a PR is opened with `ports/*/` changes
- Error classification correctly identifies Linker vs. CMake vs. Dependency errors
- Review report mirrors the structure from the original `/review-port` prompt

---

### Milestone 5: Update and Baseline Skills (Weeks 10–11)

**Goal**: Convert the update and version tracking prompts.

**Prompts converted**:
- `/update-port` → `update-port` skill
- `/update-version-baseline` → `update-version-baseline` skill

**Tasks**:
- [ ] Write `update-port/SKILL.md` with version bump and SHA512 recalculation workflow
- [ ] Bundle shared `sha512-calculation.md` (shared reference from Milestone 3)
- [ ] Write `update-version-baseline/SKILL.md` with `registry-add-version.ps1` invocation
- [ ] Test: agent handles a "update cpuinfo to latest" issue end-to-end
- [ ] Test: agent correctly updates `versions/baseline.json` after a port commit

**Acceptance Criteria**:
- Agent correctly identifies the new version tag and calculates SHA512
- `--editable` install test is run before committing version files
- Baseline update follows the two-commit pattern (port commit → version commit)

---

### Milestone 6: Integration, Documentation, and Validation (Weeks 12–13)

**Goal**: Ensure all skills work together; update all documentation; measure improvement.

**Tasks**:
- [ ] End-to-end test: agent handles a full port lifecycle (issue → create → install → review → baseline)
- [ ] Update `docs/prompt-designs.md` to document the skill layer alongside prompts
- [ ] Update `docs/references.md` with Agent Skills documentation links
- [ ] Add a "Using Skills" section to `README.md`
- [ ] Evaluate whether any existing prompts should be deprecated in favor of skills
- [ ] Document known limitations and edge cases discovered during testing

**Acceptance Criteria**:
- All 8 skills are present and pass manual validation
- Agent successfully handles port-request issues without manual prompt invocation
- Existing prompt-based workflows are unaffected (no regressions)
- Documentation clearly explains when to use prompts vs. skills

---

## 6. Use Cases for Autonomous Maintenance

The following scenarios illustrate where Agent Skills provide the most value over prompt files:

### 6.1 Autonomous Port Request Handling

**Trigger**: A GitHub Issue labeled `port-request` is assigned to the Copilot Coding Agent

**Without skills**: Maintainer must manually run `/search-port`, then `/create-port`, then `/install-port`, then `/review-port`

**With skills**: The agent automatically:
1. Detects `port-request` label → activates `search-port` skill
2. Confirms port is not already present → activates `create-port` skill
3. Generates port files → activates `install-port` skill
4. Reports results in issue comments → activates `review-port` skill for final check

**Estimated time savings**: 30–90 minutes per port request

### 6.2 Automated Version Update PRs

**Trigger**: A scheduled GitHub Action checks for upstream updates and opens a PR

**Without skills**: Maintainer must manually run `/update-port` for each outdated port

**With skills**: Agent assigned to "update port X to Y" issue:
1. Fetches new upstream release → `check-port-upstream` skill
2. Downloads and calculates new SHA512 → `update-port` skill
3. Tests installation with `--editable` → `install-port` skill
4. Commits changes and updates baseline → `update-version-baseline` skill

**Estimated time savings**: 1–3 hours per batch update cycle

### 6.3 PR Review Assistance

**Trigger**: A Pull Request is opened with changes in `ports/`

**Without skills**: Maintainer reviews manually or runs `/review-port`

**With skills**: Agent automatically validates the PR against `review-checklist.md` and posts a structured review comment with ✅/⚠️/❌ annotations

**Value**: Consistent review quality; faster CI feedback loop

### 6.4 Environment Onboarding

**Trigger**: A contributor opens an issue saying "I can't get vcpkg to work"

**Without skills**: Maintainer walks through troubleshooting steps manually or points to `docs/troubleshooting.md`

**With skills**: Agent activates `check-environment` skill and guides the contributor through validation steps, outputting a structured report

**Value**: Self-service onboarding without maintainer intervention

### 6.5 Security Update Triage

**Trigger**: A CVE is reported that affects a library in the registry

**Without skills**: Maintainer manually checks each affected port

**With skills**: The `check-port-upstream` skill detects `CVE` keywords in release notes and escalates automatically with a security classification flag

**Value**: Faster response to security issues

---

## 7. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Agent Skills format changes before GA | Medium | Medium | Pin documentation references; validate on each VS Code update |
| Skill description too broad — false activations | Medium | Low | Use scoped, precise descriptions; add "Only use for vcpkg ports in this registry" qualifier |
| Agent lacks terminal/file tool access in some contexts | Medium | High | Keep prompt files as fallback; document which contexts support autonomous operation |
| SHA512 calculation fails in sandboxed agent environments | High | Medium | Provide placeholder strategy (SHA512 = 0 + correction loop) in skill instructions |
| Skills and prompts conflict or overlap | Low | Low | Clear naming convention; prompts for interactive, skills for autonomous |
| Cross-tool skill behavior differs (VS Code vs. Claude Code) | Medium | Low | Test on VS Code Insiders first; note tool-specific sections in SKILL.md |

---

## 8. Decision Log

This section records key decisions made during planning.

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-27 | Retain prompt files alongside skills | Prompts serve interactive workflows; skills serve autonomous agent workflows. Both are valuable. |
| 2026-02-27 | Use Option B (docs/ references) for shared content | Avoids duplication; docs/ is already well-maintained |
| 2026-02-27 | Start pilot with `check-environment` | Lowest risk; no file writes; easiest to validate auto-discovery |
| 2026-02-27 | Target 13-week milestone schedule | Allows thorough testing of each skill before moving to the next |

---

## 9. References

### GitHub Copilot Skills

- [GitHub Docs: About agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills)
- [GitHub Docs: Creating agent skills for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills)
- [VS Code: Use Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- [GitHub Copilot now supports Agent Skills (Changelog)](https://github.blog/changelog/2025-12-18-github-copilot-now-supports-agent-skills/)
- [GitHub Copilot: About the Coding Agent](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent)
- [Open Agent Skills Standard](https://agentskills.io)

### GitHub Copilot Customization

- [Copilot customization cheat sheet](https://docs.github.com/en/copilot/reference/customization-cheat-sheet)
- [Prompt files documentation](https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files)
- [Prompt engineering for custom agents](https://docs.github.com/en/copilot/building-custom-agents/prompt-engineering-for-custom-agents)
- [Custom agents configuration](https://docs.github.com/en/copilot/reference/custom-agents-configuration)

### This Repository

- [Prompt Designs — current prompt set](./prompt-designs.md)
- [Guide: Create Port](./guide-create-port.md)
- [Guide: Update Port](./guide-update-port.md)
- [Guide: Update Version Baseline](./guide-update-version-baseline.md)
- [Port Change Review Checklist](./review-checklist.md)
- [Troubleshooting](./troubleshooting.md)
