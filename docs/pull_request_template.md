# 📝 Pull Request

Leave one of "Create Port" or "Port Update" below...

## 🆕 Create Port

*Delete this section if this is a port update*

- **Port Name:** `<port-name>`
- **New Version:** `<new-version>`
- **Upstream Release or Tag:** `<release-url-or-commit>`

Link `#<issue-number>` (if applicable)

### 📋 Create Port Checklist

- [ ] Port installs successfully with overlay(`vcpkg install --overlay-ports`)
- [ ] No unexpected files in port directory
- [ ] License file is properly installed(`share/<port-name>/copyright` or `VCPKG_POLICY_SKIP_COPYRIGHT_CHECK`)
- [ ] Port follows formatting(`vcpkg format-manifest --all`)
- [ ] Version baseline has been updated

For Reviewers🔎, check the followings.

- [Create Port Guide](./guide-create-port.md)
- [Source Acquisition](./guide-create-port-download.md)
- [Build Patterns](./guide-create-port-build.md)
- [Review Checklist](./review-checklist.md)

#### Build System

- CMake
- Meson
- Header-only
- Binary redistribution
- Other: `<specify>`

### Testing

- [ ] Package files(`*.pc`, `*-config.cmake`, etc) are correctly installed
- [ ] License file is present in `share/<port-name>/`

List the tested triplets:

- x64-windows
- x64-linux
- x64-osx
- Other: `<specify-triplets>`

---

## 🔄 Port Update

*Delete this section if this is a create port PR*

- **Port Name:** `<port-name>`
- **New Version:** `<new-version>`
- **Upstream Release or Tag:** `<release-url-or-commit>`

Link `#<issue-number>` (if applicable)

### 📋 Port Update Checklist

- [ ] Port installs successfully with overlay(`vcpkg install --overlay-ports`)
- [ ] No unexpected files in port directory(e.g. patch files that are not used in `portfile.cmake`)
- [ ] Port follows formatting(`vcpkg format-manifest --all`)
- [ ] Version baseline has been updated

For Reviewers🔎, check the followings.

- [Update Port Guide](./guide-update-port.md)
- [Update Version Baseline](./guide-update-version-baseline.md)
- [Review Checklist](./review-checklist.md)

#### Changes Made

- [ ] Updated version in `vcpkg.json`
- [ ] Updated `REF` in `portfile.cmake`
- [ ] Updated `SHA512` hash in `portfile.cmake`
- [ ] Updated/removed patches: `<list-changes>`

### Validation

- [ ] `vcpkg install --overlay-ports=ports <port-name>` succeeds
- [ ] Regression tested in the other ports that use changed port

List the tested triplets:

- x64-windows
- x64-linux
- x64-osx
- Other: `<specify-triplets>`
