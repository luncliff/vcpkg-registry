---
title: Review Checklist
description: Quality checklist for port review and validation
---


This document is a checklist for reviewing [create port contributions](./guide-create-port.md) and [existing port updates](./guide-update-port.md).

## 📋 Source Acquisition

### Repository Information
- [ ] Upstream hosting identified correctly (GitHub/GitLab/SourceForge/Other)
- [ ] Immutable reference used (commit hash or release tag, not branch)
- [ ] License is compatible and properly documented
- [ ] Build system correctly identified

### Acquisition Implementation
- [ ] Appropriate helper function selected:
  - [`vcpkg_from_github`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_github) for GitHub repos
  - [`vcpkg_from_gitlab`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_gitlab) for GitLab repos
  - [`vcpkg_from_sourceforge`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_sourceforge) for SourceForge projects
  - [`vcpkg_download_distfile`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_download_distfile) for direct downloads
- [ ] SHA512 hash is correct and verified
- [ ] REF points to immutable commit/tag
- [ ] Vendored dependencies removed or documented
- [ ] Patches are minimal and well-documented

## :construction: Port Update

*For port updates only*

### Version Management
- [ ] Version properly incremented in `vcpkg.json`
- [ ] Appropriate version field type used (version/version-string/version-semver/version-date)
- [ ] REF updated to match new version or upstream branch
- [ ] SHA512 hash correctly calculated and updated
- [ ] Port-version reset to 0 (unless port-specific changes needed)

### Change Assessment
- [ ] Upstream changelog reviewed for breaking changes
- [ ] API/ABI compatibility assessed
- [ ] New dependencies identified and added
- [ ] Removed dependencies cleaned up
- [ ] License changes documented (if any)

### Regression Testing
- [ ] All previously working features still function
- [ ] No new build failures introduced
- [ ] Package structure remains consistent
- [ ] Integration tests pass (if applicable)

## 🔧 Build Configuration

### Build System Implementation
- [ ] Correct build helpers used:
  - CMake: [`vcpkg_cmake_configure`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_configure) + [`vcpkg_cmake_install`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_install)
  - Meson: [`vcpkg_configure_meson`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_configure_meson) + [`vcpkg_install_meson`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_install_meson)
  - Header-only: Manual file operations or subset CMake
- [ ] Features properly mapped using [`vcpkg_check_features`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_check_features)
- [ ] Platform-specific logic is appropriate and well-guarded

### Configuration Options
- [ ] Build options are minimal and necessary
- [ ] No hardcoded paths or inappropriate defaults
- [ ] Cross-platform compatibility considered
- [ ] Static/dynamic linkage handled correctly

## 📦 Post-Install

### File Installation
- [ ] [`vcpkg_cmake_config_fixup`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_config_fixup) used with correct `CONFIG_PATH` and `PACKAGE_NAME`(Prevent case mismatch)
- [ ] [`vcpkg_fixup_pkgconfig`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_fixup_pkgconfig) if `.pc` files are detected.
- [ ] [`vcpkg_copy_tools`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_copy_tools) used for executables in both `bin` and `libexec`
- [ ] Debug directory cleanup completed
- [ ] [`vcpkg_install_copyright`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_install_copyright) properly used. If `"license": null` is used in the manifest, this can be skipped.

## 📄 Manifest (vcpkg.json)

### Basic Information
- [ ] Port name follows conventions (lowercase, hyphens)
- [ ] Appropriate version field used:
  - `version` for semantic versioning. Expect name of the release/tag.
  - `version-semver` when suffix is required
  - `version-string` when `version-semver` can't be used because of arbitrary strings
  - `version-date` follows the date of the fetching commit.
- [ ] Homepage URL is synced with the `vcpkg_from_*` functions
- [ ] `license` field matches upstream

### Dependencies
- [ ] Build tool dependencies marked with `"host": true`:
  - `vcpkg-cmake` and `vcpkg-cmake-config` for CMake projects
  - `vcpkg-tool-meson` for Meson projects
- [ ] Optional features are properly defined
- [ ] Platform-specific dependencies handled correctly

## 🧪 Installation Testing

### Basic Functionality
- [ ] Overlay installation succeeds: `vcpkg install --overlay-ports=ports <port-name>`
- [ ] Package directory structure is correct
- [ ] No build artifacts remain in package
- [ ] License file installed under `share/<port-name>/`

### Integration In Port Consumers

This part can be tested by installing the consumer port(the port that requires the changed port).
If it doesn't exists, it should be done by the developers.

- CMake `find_package()` works (if applicable)
- `pkg-config` integration works (if applicable)
- Tools can be executed in its location after the install finished
- Headers are properly installed
- Tested build/install on with [major triplets](https://github.com/microsoft/vcpkg/tree/master/triplets), based on the port's `supports` field

## 📚 Registry Maintenance

### Version Management
- [ ] Port changes committed before version registration
- [ ] Registry formatting completed
- [ ] Version baseline updated correctly
- [ ] Git commit structure follows convention:
  - Port commit: `[<port-name>] add v<version>` or `[<port-name>] update to v<version>`
  - Version commit: `[<port-name>] update baseline and version files for v<version>`
  - If multiple ports are updated, their changes should be commited following dependency order. For example, if both `cpuinfo` and `xnnpack` has changed, `cpuinfo` changes must commited first because the port is in `dependencies` of `xnnpack`.

### File Organization
- [ ] Required port files(vcpkg.json, portfile.cmake) in correct location
- [ ] No hidden, extraneous files included
- [ ] Patch files properly named or commented in portfile.cmake
- [ ] Version files correctly generated and basline is updated
