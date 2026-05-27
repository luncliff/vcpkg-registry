# GitHub Copilot Instructions: vcpkg-registry maintenance

## Introduction

This vcpkg registry provides an overlay of custom ports for the vcpkg package manager. This file defines how GitHub Copilot should assist with repository maintenance tasks.

For repository overview and setup instructions, see [README.md](README.md).

## Core Maintenance Tasks

The primary maintenance tasks for this registry are:

### 1. Create Port
**Goal:** Add a new vcpkg port to this registry.

**Documentation:**
- docs/guide-create-port.md – Main creation guide
- docs/guide-create-port-build.md – Build patterns
- docs/guide-create-port-download.md – Download & SHA512

**Skills:**
- `search-port` – .github/skills/search-port/SKILL.md
- `create-port` – .github/skills/create-port/SKILL.md
- `install-port` – .github/skills/install-port/SKILL.md
- `review-port` – .github/skills/review-port/SKILL.md

### 2. Update Port
**Goal:** Update an existing port to a newer version or adjust its build configuration.

**Documentation:**
- docs/guide-update-port.md – Update procedures

**Skills:**
- `check-port-upstream` – .github/skills/check-port-upstream/SKILL.md
- `update-port` – .github/skills/update-port/SKILL.md
- `install-port` – .github/skills/install-port/SKILL.md
- `review-port` – .github/skills/review-port/SKILL.md

### 3. Update Version Baseline
**Goal:** Synchronize `versions/` JSON files with changes to ports.

**Documentation:**
- docs/guide-update-version-baseline.md – Baseline update procedures

**Skills:**
- `update-version-baseline` – .github/skills/update-version-baseline/SKILL.md

### 4. Troubleshoot Port
**Goal:** Diagnose and fix issues with port installation or build.

**Documentation:**
- docs/troubleshooting.md – Common issues and solutions

**Skills:**
- `check-environment` – .github/skills/check-environment/SKILL.md
- `install-port` – .github/skills/install-port/SKILL.md
- `review-port` – .github/skills/review-port/SKILL.md

## How Copilot Should Use Documentation

When assisting with tasks:

1. **For setup and environment:** Reference README.md and docs/references.md
2. **For step-by-step instructions:** Use the specific guides in `docs/`:
   - docs/guide-create-port.md
   - docs/guide-update-port.md
   - docs/guide-update-version-baseline.md
   - docs/troubleshooting.md
3. **For external resources:** Use docs/references.md
4. **Skill behavior must follow the corresponding guide's process**

## How Copilot Should Use Skills

### Task-to-Skill-to-Guide Mapping

| Task | Skills | Primary Guides |
|------|--------|----------------|
| **Create port** | `search-port` → `create-port` → `install-port` → `review-port` | `guide-create-port.md`, `guide-create-port-build.md`, `guide-create-port-download.md` |
| **Update port** | `check-port-upstream` → `update-port` → `install-port` → `review-port` | `guide-update-port.md` |
| **Update version baseline** | `update-version-baseline` | `guide-update-version-baseline.md` |
| **Troubleshoot** | `check-environment` → `install-port` | `troubleshooting.md` |

### Skill Guidelines

- Skills are for **process execution** with clear pass/fail outcomes
- Each skill should report structured results with ✅ ⚠️ ❌ indicators
- Follow the workflow defined in the skill's corresponding guide

## Command Usage Guidelines

### Overlay Usage
- Use explicit CLI options (`--overlay-ports`, `--overlay-triplets`) instead of environment variables
- See docs/guide-create-port.md and docs/troubleshooting.md for examples

### Helper Scripts
Prefer helper scripts in `scripts/` when available:
- registry-add-version.ps1 – Update version baseline
- registry-format.ps1 – Format manifests files in ports folder

### Minimal Changes
- Keep changes focused on the requested task
- Avoid unrelated refactoring
- Test only what's relevant to the change

## Safety and Scope Constraints

- **No automatic commits** unless explicitly requested
- **Stay within task scope** – don't modify unrelated ports or versions
- **Run tests/installs only when relevant** to the requested change
- **Follow vcpkg best practices** as documented in guides

## Navigation Graphs

### Mermaid Diagram

```mermaid
graph TD
  README[README.md] --> CreateGuide[docs/guide-create-port.md]
  CreateGuide -- skill --> CreateSkill[create-port/SKILL.md]
  CreateGuide --> BuildGuide[docs/guide-create-port-build.md]
  CreateGuide --> DownloadGuide[docs/guide-create-port-download.md]
  CreateGuide --> Troubleshoot[docs/troubleshooting.md]

  UpdateGuide[docs/guide-update-port.md] -- skill --> UpdateSkill[update-port/SKILL.md]
  UpdateGuide --> BaselineGuide[docs/guide-update-version-baseline.md]
  BaselineGuide -- skill --> BaselineSkill[update-version-baseline/SKILL.md]
  BaselineGuide --> Troubleshoot

  Troubleshoot -- skill --> InstallSkill[install-port/SKILL.md]
  Troubleshoot -- skill --> CheckEnvSkill[check-environment/SKILL.md]

  References[docs/references.md] --> CreateGuide
  References --> UpdateGuide
```
