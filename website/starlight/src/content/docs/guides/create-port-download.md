---
title: Port Download Patterns
description: Source acquisition and download patterns for vcpkg ports
---


This guide focuses on downloading (acquiring) upstream source for a port in this registry. After reading it you should be able to choose the correct helper function and produce a minimal `vcpkg.json` + `portfile.cmake` skeleton.

See also:
- Build / install patterns: [guide-create-port-build.md](./guide-create-port-build.md)
- Planning & workflow overview: [guide-create-port.md](./guide-create-port.md)

## 1. Source Acquisition Scenarios

### GitHub Hosting

#### Tag or Release Archives
Use [`vcpkg_from_github`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_github) for projects hosted on GitHub with tagged releases.

Examples: [`ports/opencl`](../ports/opencl), [`ports/zlib-ng`](../ports/zlib-ng), [`ports/nvtx3`](../ports/nvtx3)

Supports `REF` parameter for specifying tags or commits, with optional `PATCHES` for build fixes.

### GitLab Hosting

#### Commit or Tag Archives
Use [`vcpkg_from_gitlab`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_gitlab) for projects hosted on GitLab instances.

Examples: [`ports/eigen3`](../ports/eigen3)

Requires `GITLAB_URL` + `REPO` parameters in group/project format.

### SourceForge Hosting

#### Packaged Archives
Use [`vcpkg_from_sourceforge`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_sourceforge) for projects distributed through SourceForge.

Examples: [`ports/liblzma`](../ports/liblzma)

Provide `REPO` parameter and exact `FILENAME` for the archive.

### Generic Hosting

#### Custom Distribution Points
Use [`vcpkg_download_distfile`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_download_distfile) for projects hosted on custom servers or unusual hosting platforms.

Requires manual hash calculation and manual extraction steps.

### Pre-Packaged Sources

#### Headers-Only or Subset Installation
Use any of the above acquisition methods even for header-only libraries.

Examples: `ports/nvtx3`

You can restrict installation to a specific subdirectory of the source.

## 2. Common Manifest Skeleton (`vcpkg.json`)

Keep **only what you need**. Prefer one version field (`version`, `version-string`, or `version-semver`, or `version-date`).

```jsonc
// ports/mylib/vcpkg.json
{
  "name": "mylib",
  "version": "1.2.3",
  "description": "Short, imperative summary.",
  "homepage": "https://example.com/mylib",
  "license": "MIT",
  "dependencies": [
    { "name": "vcpkg-cmake", "host": true },
    { "name": "vcpkg-cmake-config", "host": true }
  ],
  "features": {
    "tools": { "description": "Build CLI tools" }
  }
}
```

## 3. GitHub Pattern ([`vcpkg_from_github`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_github))

Use when upstream is on GitHub and you can pin a released tag or immutable commit.

```cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO owner/project              # e.g. zlib-ng/zlib-ng
    REF 2.2.2                       # tag or commit
    SHA512 0                        # put 0 first ⇒ run install to obtain real hash
    HEAD_REF main                   # convenience for --head builds
    PATCHES                         # optional
        fix-build.patch
)
```

Then fetch actual hash: run
```pwsh
vcpkg install --overlay-ports=ports mylib
```
Copy the reported SHA512 back into the portfile.

Example references:
- [`ports/zlib-ng/portfile.cmake`](../ports/zlib-ng/portfile.cmake)
- [`ports/opencl/portfile.cmake`](../ports/opencl/portfile.cmake)
- [`ports/nvtx3/portfile.cmake`](../ports/nvtx3/portfile.cmake)

### Minimal CMake-only Portfile (GitHub)
```cmake
# ports/mylib/portfile.cmake
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO owner/project
    REF v1.2.3
    SHA512 <real-sha512-here>
    HEAD_REF main
)

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS -DBUILD_TESTING=OFF)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/mylib)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
```

## 4. GitLab Pattern ([`vcpkg_from_gitlab`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_gitlab))

Use for gitlab.com (or self‑hosted) repositories.

```cmake
vcpkg_from_gitlab(
    GITLAB_URL https://gitlab.com
    OUT_SOURCE_PATH SOURCE_PATH
    REPO group/project          # e.g. libeigen/eigen
    REF <commit-or-tag>         # prefer immutable commit for reliability
    SHA512 <hash>
    HEAD_REF master
)
```

Reference: [`ports/eigen3/portfile.cmake`](../ports/eigen3/portfile.cmake).

Notes:
- Pin **commits** for fast-moving mainline projects.
- Use `SUBMODULES_RECURSE` if the project depends on git submodules.

## 5. SourceForge Pattern ([`vcpkg_from_sourceforge`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_from_sourceforge))

SourceForge releases are usually distributed as versioned archives; pick exact `FILENAME`.

```cmake
vcpkg_from_sourceforge(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO projectid_or_name   # e.g. lzmautils
    FILENAME xz-5.6.2.tar.xz
    SHA512 <hash>
)
```

Reference: [`ports/liblzma/portfile.cmake`](../ports/liblzma/portfile.cmake).

Handling platform divergence (example from liblzma):
```cmake
if(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    message(WARNING "Using system LibLZMA headers only")
    set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
    file(INSTALL "${SOURCE_PATH}/src/liblzma/api/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
    return()
endif()
```

## 6. Generic Distfile ([`vcpkg_download_distfile`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_download_distfile) + manual extract)

Use when no first-class helper covers the host. (Not yet exemplified in this repo.)

```cmake
vcpkg_download_distfile(ARCHIVE
    URLS "https://example.com/mylib-1.2.3.tar.gz"
    FILENAME mylib-1.2.3.tar.gz
    SHA512 <hash>
)

vcpkg_extract_source_archive_ex(OUT_SOURCE_PATH SOURCE_PATH ARCHIVE ${ARCHIVE})
```

## 7. Getting the SHA512 Hash

Option A (preferred): Temporarily set `SHA512 0` and run `vcpkg install` — copy the computed hash from the failure message.

Option B: Manual hash via PowerShell:
```pwsh
$Url = "https://github.com/owner/project/archive/refs/tags/v1.2.3.tar.gz"
Invoke-WebRequest -Uri $Url -OutFile tmp.tgz
(Get-FileHash -Algorithm SHA512 tmp.tgz).Hash.ToLower()
Remove-Item tmp.tgz
```

## 8. Applying Patches

Keep patches minimal; store them under the port directory.

```cmake
vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO owner/project
  REF v1.2.3
  SHA512 <hash>
  PATCHES fix-cmake.patch disable-tests.patch
)
```

When upstream churn makes patching fragile, you may embed a modified `CMakeLists.txt` (see explanation in repository root instructions) but remember: **convert to patches before contributing upstream**.

## 9. Post-Fetch Hygiene

Remove vendored dependencies to enforce use of vcpkg ports (see [`ports/etcpak/portfile.cmake`](../ports/etcpak/portfile.cmake)).
```cmake
file(REMOVE_RECURSE "${SOURCE_PATH}/third_party" "${SOURCE_PATH}/external/libpng")
```


---
**Next:** proceed to build configuration ([guide-create-port-build.md](./guide-create-port-build.md)).

Review your work with the [Contributor Checklist](./pull_request_template.md)
