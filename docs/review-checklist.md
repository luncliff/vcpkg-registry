# Port Review Checklist

This document provides a comprehensive checklist for reviewing new port contributions and port updates. It will be automatically posted as a comment on pull requests by our GitHub Action.

## 📋 Source Acquisition Review

### Repository Information
- [ ] Upstream hosting identified correctly (GitHub/GitLab/SourceForge/Other)
- [ ] Immutable reference used (commit hash or release tag, not branch)
- [ ] License is compatible and properly documented
- [ ] Build system correctly identified

### Acquisition Implementation
- [ ] Appropriate helper function selected:
  - [ ] [`vcpkg_from_github`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_github) for GitHub repos
  - [ ] [`vcpkg_from_gitlab`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_gitlab) for GitLab repos
  - [ ] [`vcpkg_from_sourceforge`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_sourceforge) for SourceForge projects
  - [ ] [`vcpkg_download_distfile`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_download_distfile) for direct downloads
- [ ] SHA512 hash is correct and verified
- [ ] REF points to immutable commit/tag
- [ ] Vendored dependencies removed or documented
- [ ] Patches are minimal and well-documented

## � Port Update Specific Review

*For port updates only*

### Version Management
- [ ] Version properly incremented in `vcpkg.json`
- [ ] Appropriate version field type used (version/version-string/version-semver/version-date)
- [ ] REF updated to match new version
- [ ] SHA512 hash correctly calculated and updated
- [ ] Port-version reset to 0 (unless port-specific changes needed)

### Change Assessment
- [ ] Upstream changelog reviewed for breaking changes
- [ ] API/ABI compatibility assessed
- [ ] New dependencies identified and added
- [ ] Removed dependencies cleaned up
- [ ] License changes documented (if any)

### Patch Management
- [ ] Existing patches tested with new version
- [ ] Obsolete patches removed
- [ ] Updated patches apply cleanly
- [ ] New patches justified and minimal
- [ ] Patch purposes documented in portfile

### Regression Testing
- [ ] All previously working features still function
- [ ] No new build failures introduced
- [ ] Package structure remains consistent
- [ ] Integration tests pass (if applicable)

## �🔧 Build Configuration Review

### Build System Implementation
- [ ] Correct build helpers used:
  - [ ] CMake: [`vcpkg_cmake_configure`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_configure) + [`vcpkg_cmake_install`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_install)
  - [ ] Meson: [`vcpkg_configure_meson`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_configure_meson) + [`vcpkg_install_meson`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_install_meson)
  - [ ] Header-only: Manual file operations or subset CMake
- [ ] Tests and examples disabled (`-DBUILD_TESTING=OFF`, `-DBUILD_EXAMPLES=OFF`)
- [ ] Features properly mapped using [`vcpkg_check_features`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_check_features)
- [ ] Platform-specific logic is appropriate and well-guarded

### Configuration Options
- [ ] Build options are minimal and necessary
- [ ] No hardcoded paths or inappropriate defaults
- [ ] Cross-platform compatibility considered
- [ ] Static/dynamic linkage handled correctly

## 📦 Post-Install Review

### File Installation
- [ ] [`vcpkg_cmake_config_fixup`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_config_fixup) used with correct `CONFIG_PATH`
- [ ] [`vcpkg_fixup_pkgconfig`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_fixup_pkgconfig) used when applicable
- [ ] [`vcpkg_copy_tools`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_copy_tools) used for executables
- [ ] Debug directory cleanup completed
- [ ] [`vcpkg_install_copyright`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_install_copyright) properly used

### Package Cleanliness
- [ ] No duplicate headers under `debug/include`
- [ ] No debug libraries in release folder
- [ ] No unnecessary build artifacts included
- [ ] Tools are in correct location (`tools/<port-name>/`)

## 📄 Manifest Review (vcpkg.json)

### Basic Information
- [ ] Port name follows conventions (lowercase, hyphens)
- [ ] Appropriate version field used:
  - [ ] `version` for semantic versioning
  - [ ] `version-string` for arbitrary strings
  - [ ] `version-semver` for strict semantic versioning
  - [ ] `version-date` for date-based versioning
- [ ] Description is concise and informative
- [ ] Homepage URL is valid and relevant
- [ ] License field matches upstream

### Dependencies
- [ ] Build tool dependencies marked with `"host": true`:
  - [ ] `vcpkg-cmake` for CMake projects
  - [ ] `vcpkg-cmake-config` for CMake projects
  - [ ] `vcpkg-tool-meson` for Meson projects
- [ ] Runtime dependencies are complete and minimal
- [ ] Optional features are properly defined
- [ ] Platform-specific dependencies handled correctly

## 🧪 Installation Testing

### Basic Functionality
- [ ] Overlay installation succeeds: `vcpkg install --overlay-ports=ports <port-name>`
- [ ] Package directory structure is correct
- [ ] No build artifacts remain in package
- [ ] License file installed under `share/<port-name>/`

### Integration Testing
- [ ] CMake `find_package()` works (if applicable)
- [ ] Pkg-config integration works (if applicable)
- [ ] Tools are accessible in PATH (if applicable)
- [ ] Headers are properly installed

### Multi-Platform Testing
- [ ] Windows builds tested where supported
- [ ] Linux builds tested where supported
- [ ] macOS builds tested where supported
- [ ] Mobile platforms tested if applicable

## 🔍 Quality Assurance

### Code Quality
- [ ] Portfile follows registry conventions
- [ ] Error handling is appropriate
- [ ] Platform detection logic is correct
- [ ] No hardcoded values that should be configurable

### Documentation
- [ ] Comments explain non-obvious decisions
- [ ] Patches are documented with purpose
- [ ] Platform limitations are noted
- [ ] Special requirements documented

### Reproducibility
- [ ] Build is deterministic
- [ ] No network access during build (after download)
- [ ] No dependency on host environment specifics
- [ ] Version is properly tracked in registry

## 📚 Registry Integration

### Version Management
- [ ] Port changes committed before version registration
- [ ] Registry formatting completed
- [ ] Version baseline updated correctly
- [ ] Git commit structure follows convention:
  - [ ] Port commit: `[<port-name>] add v<version>` or `[<port-name>] update to v<version>`
  - [ ] Version commit: `[<port-name>] update baseline and version files for v<version>`

### File Organization
- [ ] All port files in correct location
- [ ] No extraneous files included
- [ ] Patch files properly named and organized
- [ ] Version files correctly generated

## ⚠️ Security Considerations

- [ ] Source URLs use HTTPS where possible
- [ ] Downloaded archives verified with SHA512
- [ ] No execution of downloaded scripts without review
- [ ] Dependencies come from trusted sources

## 🎯 Final Review

### Completeness
- [ ] All required files present
- [ ] Documentation is adequate
- [ ] Testing is sufficient for supported platforms
- [ ] No obvious bugs or issues

### Standards Compliance
- [ ] Follows vcpkg port conventions
- [ ] Matches registry standards
- [ ] Compatible with existing ecosystem
- [ ] Ready for production use

---

## Review Decision

**Reviewer:** `@<username>`  
**Decision:** [ ] Approve [ ] Request Changes [ ] Needs Discussion  
**Comments:** `<detailed-feedback>`

---

**Additional Resources:**
- [Port Creation Guide](guide-new-port.md)
- [Port Update Guide](guide-update-port.md)
- [Source Acquisition Guide](guide-new-port-download.md)
- [Build Patterns Guide](guide-new-port-build.md)
- [Version Management Guide](guide-update-port-versioning.md)
- [vcpkg Documentation](https://learn.microsoft.com/en-us/vcpkg/)
  - [ ] CMake: [`vcpkg_cmake_configure`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_configure) + [`vcpkg_cmake_install`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_install)
  - [ ] Meson: [`vcpkg_configure_meson`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_configure_meson) + [`vcpkg_install_meson`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_install_meson)
  - [ ] Header-only: Manual file operations or subset CMake
- [ ] Tests and examples disabled (`-DBUILD_TESTING=OFF`, `-DBUILD_EXAMPLES=OFF`)
- [ ] Features properly mapped using [`vcpkg_check_features`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_check_features)
- [ ] Platform-specific logic is appropriate and well-guarded

### Configuration Options
- [ ] Build options are minimal and necessary
- [ ] No hardcoded paths or inappropriate defaults
- [ ] Cross-platform compatibility considered
- [ ] Static/dynamic linkage handled correctly

## 📦 Post-Install Review

### File Installation
- [ ] [`vcpkg_cmake_config_fixup`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_config_fixup) used with correct `CONFIG_PATH`
- [ ] [`vcpkg_fixup_pkgconfig`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_fixup_pkgconfig) used when applicable
- [ ] [`vcpkg_copy_tools`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_copy_tools) used for executables
- [ ] Debug directory cleanup completed
- [ ] [`vcpkg_install_copyright`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_install_copyright) properly used

### Package Cleanliness
- [ ] No duplicate headers under `debug/include`
- [ ] No debug libraries in release folder
- [ ] No unnecessary build artifacts included
- [ ] Tools are in correct location (`tools/<port-name>/`)

## 📄 Manifest Review (vcpkg.json)

### Basic Information
- [ ] Port name follows conventions (lowercase, hyphens)
- [ ] Appropriate version field used:
  - [ ] `version` for semantic versioning
  - [ ] `version-string` for arbitrary strings
  - [ ] `version-semver` for strict semantic versioning
  - [ ] `version-date` for date-based versioning
- [ ] Description is concise and informative
- [ ] Homepage URL is valid and relevant
- [ ] License field matches upstream

### Dependencies
- [ ] Build tool dependencies marked with `"host": true`:
  - [ ] `vcpkg-cmake` for CMake projects
  - [ ] `vcpkg-cmake-config` for CMake projects
  - [ ] `vcpkg-tool-meson` for Meson projects
- [ ] Runtime dependencies are complete and minimal
- [ ] Optional features are properly defined
- [ ] Platform-specific dependencies handled correctly

## 🧪 Installation Testing

### Basic Functionality
- [ ] Overlay installation succeeds: `vcpkg install --overlay-ports=ports <port-name>`
- [ ] Package directory structure is correct
- [ ] No build artifacts remain in package
- [ ] License file installed under `share/<port-name>/`

### Integration Testing
- [ ] CMake `find_package()` works (if applicable)
- [ ] Pkg-config integration works (if applicable)
- [ ] Tools are accessible in PATH (if applicable)
- [ ] Headers are properly installed

### Multi-Platform Testing
- [ ] Windows builds tested where supported
- [ ] Linux builds tested where supported
- [ ] macOS builds tested where supported
- [ ] Mobile platforms tested if applicable

## 🔍 Quality Assurance

### Code Quality
- [ ] Portfile follows registry conventions
- [ ] Error handling is appropriate
- [ ] Platform detection logic is correct
- [ ] No hardcoded values that should be configurable

### Documentation
- [ ] Comments explain non-obvious decisions
- [ ] Patches are documented with purpose
- [ ] Platform limitations are noted
- [ ] Special requirements documented

### Reproducibility
- [ ] Build is deterministic
- [ ] No network access during build (after download)
- [ ] No dependency on host environment specifics
- [ ] Version is properly tracked in registry

## 📚 Registry Integration

### Version Management
- [ ] Port changes committed before version registration
- [ ] Registry formatting completed
- [ ] Version baseline updated correctly
- [ ] Git commit structure follows convention:
  - [ ] Port commit: `[<port-name>] add v<version>`
  - [ ] Version commit: `[<port-name>] version metadata v<version>`

### File Organization
- [ ] All port files in correct location
- [ ] No extraneous files included
- [ ] Patch files properly named and organized
- [ ] Version files correctly generated

## ⚠️ Security Considerations

- [ ] Source URLs use HTTPS where possible
- [ ] Downloaded archives verified with SHA512
- [ ] No execution of downloaded scripts without review
- [ ] Dependencies come from trusted sources

## 🎯 Final Review

### Completeness
- [ ] All required files present
- [ ] Documentation is adequate
- [ ] Testing is sufficient for supported platforms
- [ ] No obvious bugs or issues

### Standards Compliance
- [ ] Follows vcpkg port conventions
- [ ] Matches registry standards
- [ ] Compatible with existing ecosystem
- [ ] Ready for production use

---

## Review Decision

**Reviewer:** `@<username>`  
**Decision:** [ ] Approve [ ] Request Changes [ ] Needs Discussion  
**Comments:** `<detailed-feedback>`

---

**Additional Resources:**
- [Port Creation Guide](guide-new-port.md)
- [Source Acquisition Guide](guide-new-port-download.md)
- [Build Patterns Guide](guide-new-port-build.md)
- [vcpkg Documentation](https://learn.microsoft.com/en-us/vcpkg/)