# Pull Request: New Port

## Port Information

**Port Name:** `<port-name>`  
**Version:** `<version>`  
**Upstream Repository:** `<repository-url>`  
**License:** `<license-type>`

## Description

Brief description of what this port provides and why it's useful.

## Changes Made

- [ ] Created `ports/<port-name>/vcpkg.json`
- [ ] Created `ports/<port-name>/portfile.cmake`
- [ ] Created patch files (if any): `<list-files>`
- [ ] Updated version baseline using scripts

## Testing Completed

### Basic Installation
- [ ] `vcpkg install --overlay-ports=ports <port-name>` succeeds
- [ ] Package files are correctly installed
- [ ] License file is present

### Platform Testing
Please mark all platforms where you have tested this port:

- [ ] x64-windows
- [ ] x64-linux  
- [ ] x64-osx
- [ ] Other: `<specify-triplets>`

### Feature Testing (if applicable)
- [ ] Default build works
- [ ] All features tested: `<list-features>`

## Source Information

**Acquisition Method:**
- [ ] GitHub (`vcpkg_from_github`)
- [ ] GitLab (`vcpkg_from_gitlab`)
- [ ] SourceForge (`vcpkg_from_sourceforge`)
- [ ] Other: `<specify>`

**Build System:**
- [ ] CMake
- [ ] Meson
- [ ] Header-only
- [ ] Binary redistribution
- [ ] Other: `<specify>`

## Dependencies

**Runtime Dependencies:** `<list-dependencies>`  
**Build Dependencies:** `<list-build-deps>`

## Known Issues / Limitations

`<describe-any-known-issues>`

## Checklist

- [ ] Port installs successfully with overlay
- [ ] No unexpected files in package directory
- [ ] License file is properly installed
- [ ] Port follows registry formatting standards
- [ ] Version baseline has been updated
- [ ] All commits follow naming convention

---

**For Reviewers:** A detailed review checklist will be automatically posted as a comment by our GitHub Action.

**References:**
- [Port Creation Guide](../docs/guide-new-port.md)
- [Source Acquisition](../docs/guide-new-port-download.md)
- [Build Patterns](../docs/guide-new-port-build.md)