# AGENTS.md — vcpkg-registry

Instructions for GitHub Copilot and Copilot CLI agents working on this repository.

## Repository Overview

This is a vcpkg registry providing custom overlay ports for the vcpkg package manager. See [README.md](README.md) for setup instructions and [docs/references.md](docs/references.md) for external resources.

### Structure

```
ports/           — vcpkg port definitions (portfile.cmake, vcpkg.json, patches)
versions/        — version tracking (baseline.json, per-port JSON)
triplets/        — custom triplet definitions
scripts/         — helper scripts (registry-add-version.ps1, registry-format.ps1)
docs/            — guides and references
.github/skills/  — Copilot skill definitions
```

## Safety and Scope Constraints

- **No automatic commits** unless explicitly requested by the user
- **Stay within task scope** — don't modify unrelated ports or versions
- **Run tests/installs only when relevant** to the requested change
- **Follow vcpkg best practices** as documented in guides

## Core Maintenance Tasks

### 1. Create Port

**Goal:** Add a new vcpkg port to this registry.

| Guides | Skills |
|--------|--------|
| [docs/guide-create-port.md](docs/guide-create-port.md) | `search-port`, `create-port` |
| [docs/guide-create-port-build.md](docs/guide-create-port-build.md) | `install-port`, `review-port` |
| [docs/guide-create-port-download.md](docs/guide-create-port-download.md) | |

### 2. Update Port

**Goal:** Update an existing port to a newer version or adjust its build configuration.

| Guides | Skills |
|--------|--------|
| [docs/guide-update-port.md](docs/guide-update-port.md) | `check-port-upstream`, `update-port` |
| | `install-port`, `review-port` |

### 3. Update Version Baseline

**Goal:** Synchronize `versions/` JSON files with changes to ports.

| Guides | Skills |
|--------|--------|
| [docs/guide-update-version-baseline.md](docs/guide-update-version-baseline.md) | `update-version-baseline` |

### 4. Troubleshoot Port

**Goal:** Diagnose and fix issues with port installation or build.

| Guides | Skills |
|--------|--------|
| [docs/troubleshooting.md](docs/troubleshooting.md) | `check-environment` |
| | `install-port`, `review-port` |
| | `diagnose-failed-configure` |
| | `diagnose-failed-install` |
| | `diagnose-failed-dependency` |
| | `diagnose-failed-host-dependency` |

## Skill Workflow

| Task | Skill Chain | Primary Guides |
|------|-------------|----------------|
| Create port | `search-port` → `create-port` → `install-port` → `review-port` | guide-create-port.md, guide-create-port-build.md, guide-create-port-download.md |
| Update port | `check-port-upstream` → `update-port` → `install-port` → `review-port` | guide-update-port.md |
| Update baseline | `update-version-baseline` | guide-update-version-baseline.md |
| Troubleshoot | `check-environment` → `install-port` | troubleshooting.md |
| Diagnose configure failure | `diagnose-failed-configure` → (see Coordinator Handoff) | troubleshooting.md |
| Diagnose build/install failure | `diagnose-failed-install` → (see Coordinator Handoff) | troubleshooting.md |
| Diagnose missing dependency | `diagnose-failed-dependency` → (see Coordinator Handoff) | troubleshooting.md |
| Diagnose missing host tool | `diagnose-failed-host-dependency` → (see Coordinator Handoff) | troubleshooting.md |

### Skill Guidelines

- Skills are for **process execution** with clear pass/fail outcomes
- Report structured results with ✅ ⚠️ ❌ indicators
- Follow the workflow defined in the skill's corresponding guide
- Skill definitions: `.github/skills/<name>/SKILL.md`

## Command Usage Guidelines

### Overlay Usage
- Use explicit CLI options (`--overlay-ports`, `--overlay-triplets`) instead of environment variables
- See docs/guide-create-port.md and docs/troubleshooting.md for examples

### Helper Scripts
Prefer helper scripts in `scripts/` when available:
- `registry-add-version.ps1` — Update version baseline
- `registry-format.ps1` — Format manifest files in ports folder

### Minimal Changes
- Keep changes focused on the requested task
- Avoid unrelated refactoring
- Test only what's relevant to the change

## References

- [docs/references.md](docs/references.md) — External vcpkg documentation links
- [docs/review-checklist.md](docs/review-checklist.md) — Port review criteria
- [CONTRIBUTING.md](CONTRIBUTING.md) — Contribution guidelines
