# 📝 Pull Request: New Port

Brief description of what this port provides and why it's useful.

## 📋 Checklist

- [ ] Port installs successfully with overlay
- [ ] No unexpected files in package directory
- [ ] License file is properly installed
- [ ] Port follows registry formatting standards
- [ ] Version baseline has been updated
- [ ] All commits follow naming convention

## 1. Description

Description for the manifest.(vcpkg.json file)

- Project or Upstream Repository?: `<port-name>` or `<repository-url>`
- Version?: `<version>`
- License `<license-type>`

### Dependencies

If there is an embedded(non-vcpkg installed, nested sources in the project) dependency, please leave description.

### Source Information

Leave the related item below.

#### Acquisition Method
- GitHub (`vcpkg_from_github`)
- GitLab (`vcpkg_from_gitlab`)
- SourceForge (`vcpkg_from_sourceforge`)
- Other: `<specify>`

#### Build System
- CMake
- Meson
- Header-only
- Binary redistribution
- Other: `<specify>`

## 2. Changes Made

- Created/Changed `ports/<port-name>/vcpkg.json`
- Created/Changed `ports/<port-name>/portfile.cmake`
- Updated version baseline using scripts

### Created/Removed patch files? (if any)

`<list-files>` with short descriptions.

### Known Issues / Limitations

`<describe-any-known-issues>`

## 3. Test Note

Basic Installation.

- [ ] `vcpkg install --overlay-ports=ports <port-name>` succeeds
- [ ] Package files are correctly installed
- [ ] License file is present

### Feature Testing (if applicable)

- [ ] Default build works
- [ ] All features tested: `<list-features>`

### Target Triplets

List the known triplets where you have tested this port. Or share your triplet contents in code snippet.

- [ ] x64-windows
- [ ] x64-linux  
- [ ] x64-osx
- [ ] [Other: `<specify-triplets>`](../triplets/)

# 🛠️ Pull Request: Update

(Will be updated soon)

# 🔍 For Reviewers

A detailed review checklist will be automatically posted as a comment by our GitHub Action.

### References

- [Port Creation Guide](./guide-new-port.md)
- [Source Acquisition](./guide-new-port-download.md)
- [Build Patterns](./guide-new-port-build.md)
