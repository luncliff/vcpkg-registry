# ANGLE Port - Minimal CMake Build

This port demonstrates a minimal CMake-based build for ANGLE (Almost Native Graphics Layer Engine) by analyzing GN build files and extracting core C++ sources.

## Current Status: ✅ Minimal Working Implementation

This port currently builds the **angle_common** library, successfully demonstrating the CMake build approach requested in the task.

### What's Included

- Core common utilities from `src/common/`
- Platform-specific system utilities
- Basic headers from `include/`

### What's NOT Included (Yet)

A complete ANGLE build would require adding:

1. **Compiler Library** (`src/compiler.gni` - ~478 lines)
   - GLSL/ESSL compiler
   - Shader translator
   - SPIR-V cross-compilation

2. **libANGLE Core** (`src/libGLESv2.gni` - ~695 lines)
   - OpenGL ES API implementation
   - Context management
   - State tracking
   - Validation layers

3. **Renderer Backends**
   - Direct3D 11 (Windows)
   - Vulkan (Multi-platform)
   - Metal (macOS/iOS)
   - OpenGL (Fallback)
   - Null (Testing)

4. **Additional Components**
   - Image utilities
   - GPU info utilities
   - EGL implementation
   - GLESv1_CM implementation

## Analysis of ANGLE Build System

### GN Build Structure

ANGLE uses GN (Generate Ninja) build system with the following key files:

- `BUILD.gn` (49KB) - Main build configuration
- `src/libGLESv2.gni` (695 lines) - GLESv2 library sources
- `src/compiler.gni` (478 lines) - Shader compiler sources
- `src/libANGLE/renderer/*/BUILD.gn` - Backend-specific builds

### Source File Count

Based on GNI file analysis:

```
Common sources:          ~25 files
Compiler sources:        ~100+ files
libANGLE core:           ~150+ files
D3D11 backend:           ~80+ files
Vulkan backend:          ~200+ files
Metal backend:           ~100+ files
Total estimated:         650+ source files
```

### Build Complexity

1. **Platform-specific compilation**
   - Windows: D3D11 backend as primary
   - Linux: Vulkan/OpenGL backends
   - macOS: Metal/Vulkan backends
   - iOS: Metal backend

2. **Conditional compilation**
   - Backend selection via preprocessor defines
   - Feature flags for extensions
   - Platform-specific system calls

3. **Auto-generated files**
   - `*_autogen.cpp/h` files
   - Shader conversion tables
   - Extension headers
   - Entry point wrappers

## Comparison with Other Approaches

### This Port (Minimal CMake)
- ✅ Simple to understand
- ✅ Follows farmhash pattern
- ❌ Incomplete (demo only)
- ❌ Requires manual source list maintenance

### PR #491 (Full CMake)
- ✅ Complete implementation
- ✅ All backends supported
- ❌ Too complex (full buildsystem rewrite)
- ❌ Difficult to maintain

### PR #532 (Native GN)
- ✅ Uses upstream build system
- ❌ Blocked by Chromium dependencies
- ❌ Requires gclient infrastructure
- ❌ Not practical for vcpkg

### microsoft/vcpkg (Custom CMake)
- ✅ Production-ready
- ✅ Well-tested
- ✅ Maintained
- ℹ️ Complex but stable

## Recommendations

For users needing ANGLE:

1. **Use microsoft/vcpkg's angle port** (recommended)
   - Mature, tested, maintained
   - Full backend support
   - Production-ready

2. **Wait for upstream CMake support**
   - ANGLE team may add CMake in future
   - Would simplify vcpkg integration

3. **Contribute to this port**
   - Add remaining sources from GNI files
   - Implement backend selection
   - Test on multiple platforms

## Building

This minimal port can be tested with:

```bash
vcpkg install --overlay-ports=ports angle
```

**Note**: This builds only `angle_common`, not a complete ANGLE library.

## Future Work

To complete this port:

1. Extract all source files from:
   - `src/compiler.gni`
   - `src/libGLESv2.gni`
   - `src/libANGLE/renderer/*/BUILD.gn`

2. Implement conditional backend compilation:
   ```cmake
   option(ANGLE_ENABLE_D3D11 "Enable Direct3D 11 backend" ON)
   option(ANGLE_ENABLE_VULKAN "Enable Vulkan backend" ON)
   option(ANGLE_ENABLE_METAL "Enable Metal backend" ON)
   option(ANGLE_ENABLE_OPENGL "Enable OpenGL backend" ON)
   ```

3. Add proper CMake config generation

4. Test on Windows/Linux/macOS

5. Handle platform-specific quirks

## References

- [ANGLE Repository](https://github.com/google/angle)
- [PR #532 - GN Build Analysis](https://github.com/luncliff/vcpkg-registry/pull/532)
- [PR #491 - Full CMake Port](https://github.com/luncliff/vcpkg-registry/pull/491)
- [microsoft/vcpkg ANGLE Port](https://github.com/microsoft/vcpkg/tree/master/ports/angle)
