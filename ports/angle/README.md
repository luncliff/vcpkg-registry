# ANGLE Port

## Overview

**Port Name**: angle  
**Version**: 2026-01-10  
**Commit**: [2d91f554](https://github.com/google/angle/commit/2d91f554ab55bd1bef6998ab4094f60ae3e7feb5)  
**License**: BSD-3-Clause  
**Build System**: GN (Native)  
**Status**: ⚠️ Demonstration/Non-functional

## What is ANGLE?

ANGLE (Almost Native Graphics Layer Engine) translates OpenGL ES API calls to hardware-supported APIs:
- **Windows**: Direct3D 11
- **Linux**: Vulkan, OpenGL
- **macOS/iOS**: Metal
- **Android**: Vulkan, OpenGL ES

## ⚠️ Important Notice

**This port will not build successfully.** It demonstrates an attempt to use ANGLE's native GN build system with vcpkg, but ANGLE requires Chromium's build infrastructure which is not available in GitHub source tarballs.

See **[GN_BUILD_NOTES.md](GN_BUILD_NOTES.md)** for technical details.

## Why This Port Exists

This port was created to:
1. Demonstrate proper use of `vcpkg_gn_configure` and `vcpkg_gn_install`
2. Document why GN-based ANGLE ports are not feasible
3. Explain why alternative ports use custom CMake builds
4. Provide reference for similar GN integration attempts

## Port Structure

```
ports/angle/
├── vcpkg.json                 # Port manifest (vcpkg-gn, zlib deps)
├── portfile.cmake             # GN build configuration
├── GN_BUILD_NOTES.md          # Technical blocker analysis
├── IMPLEMENTATION_SUMMARY.md  # Complete implementation docs
└── README.md                  # This file
```

## Technical Details

### Build System: GN

This port uses ANGLE's native GN build system via vcpkg functions:
- `vcpkg_gn_configure()` - Configure GN build
- `vcpkg_gn_install()` - Build and install targets

### GN Arguments

The port configures ANGLE with:
```gn
is_component_build=false
angle_enable_vulkan=true
angle_enable_gl=true
angle_has_build=false
angle_build_tests=false
angle_build_samples=false
# Platform-specific backends (D3D11, Metal, etc.)
```

### Why It Fails

ANGLE's `.gn` file requires:
```gn
import("//build/dotfile_settings.gni")
buildconfig = "//build/config/BUILDCONFIG.gn"
```

These Chromium build system files are NOT in GitHub tarballs.

## Alternatives

### To Actually Use ANGLE with vcpkg:

1. **microsoft/vcpkg's angle port** (Recommended)
   - Uses custom CMake build
   - Stable and maintained
   - Works across platforms

2. **PR #491 approach**
   - Custom CMake for this registry
   - Reference implementation available

3. **Wait for upstream**
   - ANGLE may eventually support standalone GN builds
   - Would need bundled build configuration

## References

- **Task**: [Problem statement - create angle port with GN]
- **Negative Example**: [PR #491](https://github.com/luncliff/vcpkg-registry/pull/491) - Custom CMake
- **vcpkg Functions**:
  - [vcpkg_gn_configure](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_gn_configure)
  - [vcpkg_gn_install](https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_gn_install)
- **Similar Ports**: 
  - [vcpkg-gn](https://github.com/microsoft/vcpkg/blob/master/ports/vcpkg-gn/vcpkg.json)
  - [skia](https://github.com/microsoft/vcpkg/blob/master/ports/skia/portfile.cmake) - Working GN port

## Learning Value

This port serves as documentation for:
- How to structure a vcpkg GN port
- What challenges exist with Chromium-dependent projects
- Why custom build systems are sometimes necessary
- How to document technical blockers effectively

## Questions?

See:
- [GN_BUILD_NOTES.md](GN_BUILD_NOTES.md) - Technical analysis
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - Complete docs
- [ANGLE DevSetup](https://github.com/google/angle/blob/master/doc/DevSetup.md) - Upstream docs
