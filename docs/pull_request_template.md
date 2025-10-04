# 📝 Pull Request

**Type:** [ ] New Port [ ] Port Update [ ] Documentation [ ] Otherption of the changes and why they are needed.

---

## 🆕 New Port

*Delete this section if this is a port update*

### 📋 New Port Checklist

- [ ] Port installs successfully with overlay
- [ ] No unexpected files in package directory
- [ ] License file is properly installed
- [ ] Port follows registry formatting standards
- [ ] Version baseline has been updated
- [ ] All commits follow naming convention

### Port Information

- **Port Name:** `<port-name>`
- **Version:** `<version>`
- **Upstream:** `<repository-url>`
- **License:** `<license-type>`

#### Build System
- [ ] CMake
- [ ] Meson
- [ ] Header-only
- [ ] Binary redistribution
- [ ] Other: `<specify>`

#### Testing
- [ ] `vcpkg install --overlay-ports=ports <port-name>` succeeds
- [ ] Package files are correctly installed
- [ ] License file is present in `share/<port-name>/`

**Target Triplets Tested:**
- [ ] x64-windows
- [ ] x64-linux  
- [ ] x64-osx
- [ ] Other: `<specify-triplets>`

---

## 🔄 Port Update

*Delete this section if this is a new port*

### 📋 Update Checklist

- [ ] Version updated in vcpkg.json
- [ ] SHA512 hash updated in portfile.cmake
- [ ] Patches updated or removed if no longer needed
- [ ] Port installs successfully with new version
- [ ] Version baseline has been updated
- [ ] Commits follow naming convention

### Update Information

- **Port Name:** `<port-name>`
- **Previous Version:** `<old-version>`
- **New Version:** `<new-version>`
- **Upstream Release:** `<release-url-or-commit>`

#### Changes Made
- [ ] Updated version in `vcpkg.json`
- [ ] Updated `REF` in `portfile.cmake`
- [ ] Updated `SHA512` hash in `portfile.cmake`
- [ ] Updated/removed patches: `<list-changes>`

#### Validation
- [ ] `vcpkg install --overlay-ports=ports <port-name>` succeeds
- [ ] No regression in functionality
- [ ] License file properly installed

**Target Triplets Verified:**
- [ ] x64-windows
- [ ] x64-linux
- [ ] x64-osx
- [ ] Other: `<specify-triplets>`

---

## � Common Information

### Known Issues / Limitations
`<describe-any-known-issues>`

### Testing Notes
`<additional-testing-information>`

### Breaking Changes
- [ ] No breaking changes
- [ ] Breaking changes (describe below)

`<describe-breaking-changes-if-any>`

---

## 🔍 For Reviewers

### Related Issues
Closes #`<issue-number>` (if applicable)

### References
- [Port Creation Guide](./guide-new-port.md)
- [Port Update Guide](./guide-update-port.md)
- [Source Acquisition](./guide-new-port-download.md)
- [Build Patterns](./guide-new-port-build.md)
- [Version Management](./guide-update-port-versioning.md)
- [Patch Maintenance](./guide-update-port-patches.md)
- [Review Checklist](./review-checklist.md)
