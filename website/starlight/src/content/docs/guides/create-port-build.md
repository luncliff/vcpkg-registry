---
title: Port Build Patterns
description: Build and installation patterns for vcpkg ports
---


This guide covers how to configure, build, and install sources after acquisition. Acquisition helpers are documented in [guide-create-port-download.md](./guide-create-port-download.md).

See also:
- [Planning overview](./guide-create-port.md)

## 1. Build System Scenarios

### CMake Projects

#### Standard CMake Project
Use [vcpkg_cmake_configure](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_configure) + [vcpkg_cmake_install](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_install) + [vcpkg_cmake_config_fixup](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_config_fixup) for most CMake-based projects.

Examples: [`opencl`](../ports/opencl), [`zlib-ng`](../ports/zlib-ng), [`eigen3`](../ports/eigen3)

This approach handles adding/overriding options and managing config path adjustments.

#### Header-Only or Subset CMake Projects
Use [`vcpkg_cmake_configure`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_cmake_configure) subset or manual copy for projects that don't require full compilation.

Examples: [`nvtx3`](../ports/nvtx3)

May set `VCPKG_BUILD_TYPE` or remove debug directories for optimization.

### Meson Projects
Use [`vcpkg_configure_meson`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_configure_meson) + [`vcpkg_install_meson`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_install_meson) for Meson-based build systems.

Examples: [`etcpak`](../ports/etcpak)

Convert feature toggles to true/false format for Meson compatibility.

### Binary Packages

#### NuGet Binary Package
Use [`vcpkg_find_acquire_program`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_find_acquire_program) + manual `file(INSTALL ...)` for pre-compiled binary packages.

Examples: [`directml`](../ports/directml)

No compilation required; focus on relocating binaries and headers to proper locations.

### Tool and Executable Management

#### Tool-Only or Extra Executables
Use [`vcpkg_copy_tools`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_copy_tools) for managing compiled tools and executables.

Examples: [`etcpak`](../ports/etcpak), [`liblzma`](../ports/liblzma)

Use `AUTO_CLEAN` option to remove unused wrappers automatically.

### Configuration Management

#### Pkg-config Generation
Use [`vcpkg_fixup_pkgconfig`](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_fixup_pkgconfig) for projects that generate pkg-config files.

Examples: [`eigen3`](../ports/eigen3), [`zlib-ng`](../ports/zlib-ng), [`liblzma`](../ports/liblzma)

Run this helper after install but before cleanup steps.

## 2. Common CMake Pattern

```cmake
# Minimal CMake-based port
vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    -DBUILD_TESTING=OFF
)

vcpkg_cmake_install()

# Adjust CONFIG_PATH to upstream install location
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/mylib)

# Optional: fix pkg-config files if upstream generated them
# vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
```

### With Feature Options
Use [vcpkg_check_features](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_check_features) to map logical feature names to CMake variables.
```cmake
vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTS
  FEATURES
    tools BUILD_TOOLS
    simd  ENABLE_SIMD
)

vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    ${FEATURE_OPTS}
    -DBUILD_TESTING=OFF
)
```

### Separate Release / Debug Install Paths
```cmake
vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS -DBUILD_TESTING=OFF
  OPTIONS_RELEASE -DENABLE_OPTIMIZED=ON
  OPTIONS_DEBUG   -DENABLE_ASSERTS=ON
)
```

### Post-Install Config Fix
If upstream puts configs in a nonstandard folder:
```cmake
vcpkg_cmake_config_fixup(CONFIG_PATH share/mylib/cmake PACKAGE_NAME MyLib)
```

## 3. Header-Only Optimization

When the library is header-only (e.g. `nvtx3`):
```cmake
set(VCPKG_BUILD_TYPE release) # skip debug variant
# Standard configure/install still ensures correct integration files
```
Remove unused lib or debug directories afterwards.

## 4. Meson Pattern

Reference: [`ports/etcpak/portfile.cmake`](../ports/etcpak/portfile.cmake).

```cmake
vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
  FEATURES
    tracy tracy_enable
    tool  build_tool
)
# Convert ON/OFF to Meson booleans
string(REPLACE "OFF" "false" FEATURE_OPTIONS "${FEATURE_OPTIONS}")
string(REPLACE "ON"  "true"  FEATURE_OPTIONS "${FEATURE_OPTIONS}")

vcpkg_configure_meson(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    ${FEATURE_OPTIONS}
)

vcpkg_install_meson()

if("tool" IN_LIST FEATURES)
  vcpkg_copy_tools(TOOL_NAMES etcpak AUTO_CLEAN)
endif()
```

Notes:
- Meson options often appear in `meson_options.txt`.
- Some Meson projects require removing bundled subprojects to use external dependencies.

## 5. NuGet Binary Relocation Pattern

Reference: [`ports/directml/portfile.cmake`](../ports/directml/portfile.cmake).

```cmake
vcpkg_find_acquire_program(NUGET)
set(ENV{NUGET_PACKAGES} "${BUILDTREES_DIR}/nuget")

set(PACKAGE_NAME    "Vendor.Library")
set(PACKAGE_VERSION "1.2.3")

vcpkg_execute_required_process(
  COMMAND ${NUGET} install "${PACKAGE_NAME}" -Version "${PACKAGE_VERSION}" -Verbosity detailed -OutputDirectory "${CURRENT_BUILDTREES_DIR}"
  WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
  LOGNAME install-nuget
)

get_filename_component(SOURCE_PATH "${CURRENT_BUILDTREES_DIR}/${PACKAGE_NAME}.${PACKAGE_VERSION}" ABSOLUTE)

# Triplet mapping
if(VCPKG_TARGET_IS_WINDOWS AND VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
  set(NUGET_LAYOUT x64-win)
else()
  message(FATAL_ERROR "Unsupported architecture")
endif()

file(INSTALL "${SOURCE_PATH}/bin/${NUGET_LAYOUT}/VendorLib.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
file(INSTALL "${SOURCE_PATH}/bin/${NUGET_LAYOUT}/VendorLib.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
```

Key Points:
- Always remove empty/unused debug directory if no debug artifacts exist.
- Provide meaningful fatal errors for unsupported architectures.

## 6. Tools / Executables

Use `vcpkg_copy_tools` after install to place compiled tools into the package and clean build-only artifacts.
```cmake
vcpkg_copy_tools(TOOL_NAMES mycli another-tool AUTO_CLEAN)
```

## 7. Pkg-Config and CMake Configs

Run these after install to adjust metadata paths:
```cmake
vcpkg_fixup_pkgconfig()              # fix .pc prefix paths
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/mylib PACKAGE_NAME MyLib)
```
If multiple config locations exist (debug/release), ensure upstream install places them consistently using `OPTIONS_DEBUG/OPTIONS_RELEASE` (see [`eigen3`](../ports/eigen3)).

## 8. Cleanup Patterns

Common removable paths:
```cmake
file(REMOVE_RECURSE
  "${CURRENT_PACKAGES_DIR}/debug/include"
  "${CURRENT_PACKAGES_DIR}/debug/share"
  "${CURRENT_PACKAGES_DIR}/share/man"   # if manpages not desired
)
```
Static-only builds can remove runtime bins:
```cmake
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
  file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin" "${CURRENT_PACKAGES_DIR}/debug/bin")
endif()
```

## 9. Licensing

Always install a license or copyright file:
```cmake
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
```
For nonstandard names (e.g. `LICENSE.md`, `COPYING`), specify the correct file.

## 10. Build Phase Checklist

To keep a single authoritative checklist for contributors, please follow the consolidated checklist in the docs:

[Contributor Checklist](./pull_request_template.md)

---
Next: see [guide-create-port.md](./guide-create-port.md) for the end-to-end workflow.
