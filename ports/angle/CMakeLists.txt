cmake_minimum_required(VERSION 3.15)
project(angle LANGUAGES CXX C)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(GNUInstallDirs)

# Platform detection
if(WIN32)
    set(ANGLE_PLATFORM_WINDOWS TRUE)
elseif(APPLE)
    set(ANGLE_PLATFORM_APPLE TRUE)
elseif(UNIX)
    set(ANGLE_PLATFORM_LINUX TRUE)
endif()

# Find dependencies
find_package(ZLIB REQUIRED)

# Common definitions
add_compile_definitions(
    ANGLE_STANDALONE_BUILD
    GL_GLES_PROTOTYPES=1
    EGL_EGL_PROTOTYPES=1
    GL_GLEXT_PROTOTYPES
    EGL_EGLEXT_PROTOTYPES
)

if(WIN32)
    add_compile_definitions(ANGLE_IS_WIN)
elseif(APPLE)
    add_compile_definitions(ANGLE_PLATFORM_APPLE)
elseif(UNIX)
    add_compile_definitions(ANGLE_IS_LINUX)
endif()

# ANGLE Common Library (minimal subset for demonstration)
# This is a minimal implementation showing the structure.
# A full implementation would need to include all sources from src/libGLESv2.gni
add_library(angle_common STATIC
    # Common sources from libangle_common_sources
    src/common/Float16ToFloat32.cpp
    src/common/MemoryBuffer.cpp
    src/common/PackedEGLEnums_autogen.cpp
    src/common/PackedEnums.cpp
    src/common/PackedGLEnums_autogen.cpp
    src/common/PoolAlloc.cpp
    src/common/SimpleMutex.cpp
    src/common/WorkerThread.cpp
    src/common/aligned_memory.cpp
    src/common/angleutils.cpp
    src/common/base/anglebase/sha1.cc
    src/common/debug.cpp
    src/common/entry_points_enum_autogen.cpp
    src/common/event_tracer.cpp
    src/common/mathutil.cpp
    src/common/matrix_utils.cpp
    src/common/platform_helpers.cpp
    src/common/string_utils.cpp
    src/common/system_utils.cpp
    src/common/tls.cpp
    src/common/uniform_type_info_autogen.cpp
    src/common/utilities.cpp
)

# Platform-specific sources
if(WIN32)
    target_sources(angle_common PRIVATE
        src/common/system_utils_win.cpp
    )
elseif(APPLE)
    target_sources(angle_common PRIVATE
        src/common/system_utils_apple.cpp
        src/common/system_utils_posix.cpp
    )
elseif(UNIX)
    target_sources(angle_common PRIVATE
        src/common/system_utils_linux.cpp
        src/common/system_utils_posix.cpp
    )
endif()

target_include_directories(angle_common
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/common/base>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(angle_common
    PUBLIC
        ZLIB::ZLIB
)

# Set library properties
set_target_properties(angle_common PROPERTIES
    PUBLIC_HEADER "include/EGL/egl.h;include/EGL/eglext.h;include/EGL/eglplatform.h;include/GLES2/gl2.h;include/GLES2/gl2ext.h;include/GLES2/gl2platform.h;include/GLES3/gl3.h;include/GLES3/gl31.h;include/GLES3/gl32.h;include/GLES3/gl3platform.h;include/KHR/khrplatform.h"
    OUTPUT_NAME "angle_common"
)

# Installation
install(TARGETS angle_common
    EXPORT angle-config
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/ANGLE
)

install(EXPORT angle-config
    DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/angle
    NAMESPACE angle::
)

# Install headers preserving directory structure
install(DIRECTORY include/
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    FILES_MATCHING PATTERN "*.h"
)

# Note: This is a minimal demonstration build.
# A complete ANGLE port would require:
# 1. Full compiler library (src/compiler.gni - 478 lines)
# 2. libANGLE library with renderer backends (src/libGLESv2.gni - 695 lines)
# 3. Platform-specific backend selection (D3D11/Vulkan/Metal/OpenGL)
# 4. Image utilities
# 5. GPU info utilities
# 6. Complete EGL and GLESv2 entry points
#
# See the referenced GN build files for the complete source list:
# - src/libGLESv2.gni (main library sources)
# - src/compiler.gni (shader compiler sources)
# - src/libANGLE/renderer/*/BUILD.gn (backend-specific sources)
