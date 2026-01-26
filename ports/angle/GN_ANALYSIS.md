# ANGLE GN Build System Analysis

This document shows the analysis of ANGLE's GN build system to extract C++ source lists for CMake building.

## GN Build Files Analyzed

### Primary Build Configuration Files

1. **BUILD.gn** (49,077 bytes)
   - Main entry point for the build system
   - Defines compilation flags, options, and target selection
   - Contains ~300 lines of build configuration

2. **src/libGLESv2.gni** (695 lines)
   - Main source list for GLESv2 implementation
   - Contains libangle_common_sources, libangle_sources, etc.
   - Key file for extracting core library sources

3. **src/compiler.gni** (478 lines)
   - GLSL/ESSL shader compiler source lists
   - Contains translator, preprocessor, and AST sources
   - Required for complete ANGLE implementation

### Backend-Specific GNI Files

- `src/libANGLE/renderer/d3d/d3d_backend.gni` - Direct3D 9/11 backend
- `src/libANGLE/renderer/vulkan/vulkan_backend.gni` - Vulkan backend
- `src/libANGLE/renderer/metal/metal_backend.gni` - Metal backend (macOS/iOS)
- `src/libANGLE/renderer/gl/gl_backend.gni` - OpenGL backend
- `src/libANGLE/renderer/null/null_backend.gni` - Null backend (testing)

## Source File Extraction

### libangle_common_sources (from src/libGLESv2.gni)

Core common utility sources extracted:

```gni
libangle_common_sources = libangle_common_headers + [
    "src/common/Float16ToFloat32.cpp",
    "src/common/MemoryBuffer.cpp",
    "src/common/PackedEGLEnums_autogen.cpp",
    "src/common/PackedEnums.cpp",
    "src/common/PackedGLEnums_autogen.cpp",
    "src/common/PoolAlloc.cpp",
    "src/common/SimpleMutex.cpp",
    "src/common/WorkerThread.cpp",
    "src/common/aligned_memory.cpp",
    "src/common/angleutils.cpp",
    "src/common/base/anglebase/sha1.cc",
    "src/common/debug.cpp",
    "src/common/entry_points_enum_autogen.cpp",
    "src/common/event_tracer.cpp",
    "src/common/mathutil.cpp",
    "src/common/matrix_utils.cpp",
    "src/common/platform_helpers.cpp",
    "src/common/string_utils.cpp",
    "src/common/system_utils.cpp",
    "src/common/tls.cpp",
    "src/common/uniform_type_info_autogen.cpp",
    "src/common/utilities.cpp",
]
```

### Platform-Specific Sources

**Android:**
```gni
libangle_common_sources += [ "src/common/backtrace_utils_android.cpp" ]
```

**Other platforms:**
```gni
libangle_common_sources += [ "src/common/backtrace_utils_noop.cpp" ]
```

**Linux:**
```gni
libangle_common_sources += [
    "src/common/system_utils_linux.cpp",
    "src/common/system_utils_posix.cpp",
]
```

**macOS:**
```gni
libangle_common_sources += [
    "src/common/system_utils_apple.cpp",
    "src/common/system_utils_posix.cpp",
]
```

**Windows:**
```gni
libangle_common_sources += [ "src/common/system_utils_win.cpp" ]
```

### Header Include Structure

Key finding: ANGLE uses `anglebase` prefix for Chromium base library includes:

```cpp
#include <anglebase/numerics/safe_math.h>
```

Actual location: `src/common/base/anglebase/numerics/safe_math.h`

**Solution:** Add `src/common/base` to include directories so `<anglebase/...>` resolves correctly.

## CMake Translation

### Include Directories

```cmake
target_include_directories(angle_common
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include      # Public headers (EGL, GLES)
        ${CMAKE_CURRENT_SOURCE_DIR}/src          # ANGLE internal headers
        ${CMAKE_CURRENT_SOURCE_DIR}/src/common/base  # anglebase includes
)
```

### Preprocessor Definitions

From BUILD.gn, key defines:

```cmake
add_compile_definitions(
    ANGLE_STANDALONE_BUILD        # Not building within Chromium
    GL_GLES_PROTOTYPES=1         # Enable GL function prototypes
    EGL_EGL_PROTOTYPES=1         # Enable EGL function prototypes
    GL_GLEXT_PROTOTYPES          # Enable GL extension prototypes
    EGL_EGLEXT_PROTOTYPES        # Enable EGL extension prototypes
)

# Platform-specific
if(WIN32)
    add_compile_definitions(ANGLE_IS_WIN)
elseif(APPLE)
    add_compile_definitions(ANGLE_PLATFORM_APPLE)
elseif(UNIX)
    add_compile_definitions(ANGLE_IS_LINUX)
endif()
```

## Complete ANGLE Build Requirements

To build the full ANGLE library (not implemented in this minimal port), the following would be needed:

### 1. Compiler Library (~100+ files)

From `src/compiler.gni`:
- Shader translator (GLSL ES → HLSL/SPIR-V/MSL)
- Preprocessor
- AST (Abstract Syntax Tree)
- Symbol tables
- Built-in functions

### 2. libANGLE Core (~150+ files)

From `src/libGLESv2.gni`:
- OpenGL ES API implementation
- Context management
- State tracking
- Validation layers
- Buffer, texture, shader, program objects
- Framebuffer management

### 3. Renderer Backends

**D3D11 Backend** (~80+ files):
```
src/libANGLE/renderer/d3d/d3d11/*.cpp
```

**Vulkan Backend** (~200+ files):
```
src/libANGLE/renderer/vulkan/*.cpp
```

**Metal Backend** (~100+ files):
```
src/libANGLE/renderer/metal/*.mm
```

**OpenGL Backend** (~120+ files):
```
src/libANGLE/renderer/gl/**/*.cpp
```

### 4. Additional Components

- Image utilities (`src/image_util/`)
- GPU info utilities (`src/gpu_info_util/`)
- EGL implementation (`src/libEGL/`)
- GLES1 CM implementation (`src/libGLESv1_CM/`)

## Source File Count Summary

```
Category                Files    Lines (est)
─────────────────────────────────────────────
Common utilities          ~25      ~3,000
Compiler                 ~100     ~15,000
libANGLE core            ~150     ~50,000
D3D11 backend            ~80      ~25,000
Vulkan backend           ~200     ~60,000
Metal backend            ~100     ~30,000
OpenGL backend           ~120     ~35,000
Image utilities          ~30      ~8,000
GPU info                 ~20      ~5,000
EGL                      ~10      ~3,000
GLES1                    ~15      ~4,000
───────────────────────────────────────────── 
Total                   ~850+    ~238,000+
```

## Build Complexity Analysis

### Auto-Generated Files

ANGLE heavily uses code generation:

```
*_autogen.cpp
*_autogen.h
format_map_autogen.cpp
es3_copy_conversion_table_autogen.cpp
gles_extensions_autogen.cpp
PackedGLEnums_autogen.cpp
PackedEGLEnums_autogen.cpp
```

These are generated from:
- `gen_*.py` Python scripts
- JSON data files
- Build-time processing

### Backend Selection

GN uses `angle_enable_*` flags:

```gni
if (angle_enable_d3d11) {
  libangle_sources += libangle_d3d11_backend_sources
}
if (angle_enable_vulkan) {
  libangle_sources += libangle_vulkan_backend_sources
}
if (angle_enable_metal) {
  libangle_sources += libangle_metal_backend_sources
}
```

CMake equivalent would need:

```cmake
option(ANGLE_ENABLE_D3D11 "Enable Direct3D 11 backend" ON)
option(ANGLE_ENABLE_VULKAN "Enable Vulkan backend" ON)
option(ANGLE_ENABLE_METAL "Enable Metal backend" ${APPLE})
option(ANGLE_ENABLE_OPENGL "Enable OpenGL backend" ON)
```

## Recommendations for Complete Implementation

1. **Extract all source lists from GNI files**
   - Parse or manually transcribe each backend's source list
   - Handle platform-specific conditional compilation

2. **Implement backend selection logic**
   - CMake options for each backend
   - Conditional source file inclusion
   - Platform-specific validation

3. **Handle auto-generated files**
   - Either check in generated files, or
   - Run Python generators during CMake configure

4. **Add external dependencies**
   - Vulkan SDK (for Vulkan backend)
   - DirectX SDK (for D3D backend on older Windows)
   - Metal framework (for Metal backend)

5. **Test across platforms**
   - Windows (D3D11 primary)
   - Linux (Vulkan/OpenGL)
   - macOS (Metal/Vulkan)
   - Android (Vulkan/GLES)

## References

- [ANGLE BUILD.gn](https://github.com/google/angle/blob/main/BUILD.gn)
- [libGLESv2.gni](https://github.com/google/angle/blob/main/src/libGLESv2.gni)
- [compiler.gni](https://github.com/google/angle/blob/main/src/compiler.gni)
- [GN Reference](https://gn.googlesource.com/gn/+/main/docs/reference.md)
