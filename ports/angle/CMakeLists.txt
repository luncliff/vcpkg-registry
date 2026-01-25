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
# Use CONFIG mode for vcpkg compatibility (especially on Emscripten)
find_package(ZLIB CONFIG REQUIRED)

# Common definitions
add_compile_definitions(
    ANGLE_STANDALONE_BUILD
    GL_GLES_PROTOTYPES=1
    EGL_EGL_PROTOTYPES=1
    # TODO: testing ANGLE internal declarations
    # GL_GLEXT_PROTOTYPES
    # EGL_EGLEXT_PROTOTYPES
)

if(WIN32)
    add_compile_definitions(ANGLE_IS_WIN)
    add_compile_definitions(
        WIN32_LEAN_AND_MEAN
        NOMINMAX
    )
elseif(APPLE)
    add_compile_definitions(ANGLE_PLATFORM_APPLE)
elseif(UNIX)
    add_compile_definitions(ANGLE_IS_LINUX)
endif()

# ============================================================================
# ANGLE Common Library (full libangle_common_sources from GN)
# ============================================================================
add_library(angle_common STATIC
    # Core common sources (platform-independent)
    src/common/Float16ToFloat32.cpp
    src/common/MemoryBuffer.cpp
    src/common/PackedEGLEnums_autogen.cpp
    src/common/PackedEnums.cpp
    src/common/PackedGLEnums_autogen.cpp
    src/common/PoolAlloc.cpp
    src/common/SimpleMutex.cpp
    src/common/WorkerThread.cpp
    src/common/aligned_memory.cpp
    src/common/android_util.cpp
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
    # Backtrace utilities (non-Android)
    src/common/backtrace_utils_noop.cpp
    # xxhash (third-party utility)
    src/common/third_party/xxhash/xxhash.c
)

# Platform-specific sources for angle_common
if(WIN32)
    target_sources(angle_common PRIVATE
        src/common/system_utils_win.cpp
    )
    if(ANGLE_IS_WINUWP)
        target_sources(angle_common PRIVATE src/common/system_utils_winuwp.cpp)
    else()
        target_sources(angle_common PRIVATE src/common/system_utils_win32.cpp)
    endif()
elseif(APPLE)
    target_sources(angle_common PRIVATE
        src/common/system_utils_apple.cpp
        src/common/system_utils_posix.cpp
        src/common/apple_platform_utils.mm
    )
elseif(UNIX)
    target_sources(angle_common PRIVATE
        src/common/system_utils_linux.cpp
        src/common/system_utils_posix.cpp
    )
endif()

# ==============================================================================
# angle_image_util - Image format conversion and utilities
# ==============================================================================
add_library(angle_image_util STATIC)
target_sources(angle_image_util PRIVATE
    # Core image utilities
    src/image_util/copyimage.cpp
    src/image_util/imageformats.cpp
    src/image_util/loadimage.cpp
    src/image_util/loadimage_astc.cpp
    src/image_util/loadimage_etc.cpp
    src/image_util/loadimage_paletted.cpp
    src/image_util/storeimage_paletted.cpp
    # ASTC decompressor (no-op version, avoiding third_party/astc-encoder)
    src/image_util/AstcDecompressorNoOp.cpp
)
target_include_directories(angle_image_util
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)
target_link_libraries(angle_image_util PRIVATE angle_common)
target_compile_definitions(angle_image_util PRIVATE
    LIBANGLE_IMPLEMENTATION
)

# ==============================================================================
# angle_gpu_info_util - GPU/System information detection
# ==============================================================================
add_library(angle_gpu_info_util STATIC)
target_sources(angle_gpu_info_util PRIVATE
    src/gpu_info_util/SystemInfo.cpp
    src/gpu_info_util/SystemInfo.h
    src/gpu_info_util/SystemInfo_internal.h
)
if(WIN32)
    target_sources(angle_gpu_info_util PRIVATE
        src/gpu_info_util/SystemInfo_win.cpp
    )
    target_link_libraries(angle_gpu_info_util PRIVATE dxgi.lib setupapi.lib)
endif()
target_include_directories(angle_gpu_info_util
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)
target_link_libraries(angle_gpu_info_util PRIVATE angle_common)
target_compile_definitions(angle_gpu_info_util PRIVATE
    LIBANGLE_IMPLEMENTATION
)

# ==============================================================================
# angle_translator - GLSL/ESSL shader compiler  
# NOTE: This is a large library (~250+ files). For Phase 1, we include:
# - Core translator (parser, AST, symbol table, type system)
# - ESSL/GLSL output backends
# - Tree transformation passes
# Excluded for Phase 1: MSL, WGSL, SPIRV backends
# ==============================================================================
# ============================================================================
# angle_translator - GLSL/ESSL shader compiler (core + HLSL/GLSL backends)
# ============================================================================
add_library(angle_translator STATIC)

# Use a glob for the translator, but drop backends we don't want (MSL/WGSL/SPIR-V/IR)
file(GLOB_RECURSE TRANSLATOR_SOURCES
    "src/compiler/translator/*.cpp"
)
list(FILTER TRANSLATOR_SOURCES EXCLUDE REGEX ".*/msl/.*")
list(FILTER TRANSLATOR_SOURCES EXCLUDE REGEX ".*/wgsl/.*")
list(FILTER TRANSLATOR_SOURCES EXCLUDE REGEX ".*/spirv/.*")
list(FILTER TRANSLATOR_SOURCES EXCLUDE REGEX ".*/ir/.*")
list(FILTER TRANSLATOR_SOURCES EXCLUDE REGEX ".*/apple/.*")
list(FILTER TRANSLATOR_SOURCES EXCLUDE REGEX ".*TranslatorMSL.*")
list(FILTER TRANSLATOR_SOURCES EXCLUDE REGEX ".*TranslatorWGSL.*")
list(FILTER TRANSLATOR_SOURCES EXCLUDE REGEX ".*TranslatorSPIRV.*")
list(FILTER TRANSLATOR_SOURCES EXCLUDE REGEX ".*TranslatorNULL.*")

target_sources(angle_translator PRIVATE ${TRANSLATOR_SOURCES})

target_include_directories(angle_translator
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/translator
)
target_link_libraries(angle_translator PRIVATE angle_common)
target_compile_definitions(angle_translator PRIVATE
    LIBANGLE_IMPLEMENTATION
    ANGLE_ENABLE_ESSL=1
    ANGLE_ENABLE_GLSL=1
    ANGLE_ENABLE_HLSL=1
)

# ============================================================================
# libANGLE core + Null renderer backend
# ============================================================================
set(LIBANGLE_SOURCES
    src/libANGLE/AttributeMap.cpp
    src/libANGLE/BlobCache.cpp
    src/libANGLE/Buffer.cpp
    src/libANGLE/Caps.cpp
    src/libANGLE/Compiler.cpp
    src/libANGLE/Config.cpp
    src/libANGLE/Context.cpp
    src/libANGLE/ContextMutex.cpp
    src/libANGLE/Context_gles_1_0.cpp
    src/libANGLE/Debug.cpp
    src/libANGLE/Device.cpp
    src/libANGLE/Display.cpp
    src/libANGLE/EGLSync.cpp
    src/libANGLE/Error.cpp
    src/libANGLE/Fence.cpp
    src/libANGLE/Framebuffer.cpp
    src/libANGLE/FramebufferAttachment.cpp
    src/libANGLE/GLES1Renderer.cpp
    src/libANGLE/GLES1State.cpp
    src/libANGLE/GlobalMutex.cpp
    src/libANGLE/HandleAllocator.cpp
    src/libANGLE/Image.cpp
    src/libANGLE/ImageIndex.cpp
    src/libANGLE/IndexRangeCache.cpp
    src/libANGLE/LoggingAnnotator.cpp
    src/libANGLE/MemoryObject.cpp
    src/libANGLE/MemoryProgramCache.cpp
    src/libANGLE/MemoryShaderCache.cpp
    src/libANGLE/Observer.cpp
    src/libANGLE/Overlay.cpp
    src/libANGLE/OverlayWidgets.cpp
    src/libANGLE/Overlay_autogen.cpp
    src/libANGLE/Overlay_font_autogen.cpp
    src/libANGLE/PixelLocalStorage.cpp
    src/libANGLE/Platform.cpp
    src/libANGLE/Program.cpp
    src/libANGLE/ProgramExecutable.cpp
    src/libANGLE/ProgramLinkedResources.cpp
    src/libANGLE/ProgramPipeline.cpp
    src/libANGLE/Query.cpp
    src/libANGLE/Renderbuffer.cpp
    src/libANGLE/ResourceManager.cpp
    src/libANGLE/Sampler.cpp
    src/libANGLE/Semaphore.cpp
    src/libANGLE/Shader.cpp
    src/libANGLE/ShareGroup.cpp
    src/libANGLE/State.cpp
    src/libANGLE/Stream.cpp
    src/libANGLE/Surface.cpp
    src/libANGLE/Texture.cpp
    src/libANGLE/Thread.cpp
    src/libANGLE/TransformFeedback.cpp
    src/libANGLE/Uniform.cpp
    src/libANGLE/VaryingPacking.cpp
    src/libANGLE/VertexArray.cpp
    src/libANGLE/VertexAttribute.cpp
    src/libANGLE/angletypes.cpp
    src/libANGLE/es3_copy_conversion_table_autogen.cpp
    src/libANGLE/format_map_autogen.cpp
    src/libANGLE/formatutils.cpp
    src/libANGLE/gles_extensions_autogen.cpp
    src/libANGLE/queryconversions.cpp
    src/libANGLE/queryutils.cpp
    src/libANGLE/renderer/BufferImpl.cpp
    src/libANGLE/renderer/ContextImpl.cpp
    src/libANGLE/renderer/DeviceImpl.cpp
    src/libANGLE/renderer/DisplayImpl.cpp
    src/libANGLE/renderer/EGLReusableSync.cpp
    src/libANGLE/renderer/EGLSyncImpl.cpp
    src/libANGLE/renderer/Format_table_autogen.cpp
    src/libANGLE/renderer/FramebufferImpl.cpp
    src/libANGLE/renderer/ImageImpl.cpp
    src/libANGLE/renderer/ProgramImpl.cpp
    src/libANGLE/renderer/ProgramPipelineImpl.cpp
    src/libANGLE/renderer/QueryImpl.cpp
    src/libANGLE/renderer/RenderbufferImpl.cpp
    src/libANGLE/renderer/ShaderImpl.cpp
    src/libANGLE/renderer/SurfaceImpl.cpp
    src/libANGLE/renderer/TextureImpl.cpp
    src/libANGLE/renderer/TransformFeedbackImpl.cpp
    src/libANGLE/renderer/VertexArrayImpl.cpp
    src/libANGLE/renderer/driver_utils.cpp
    src/libANGLE/renderer/load_functions_table_autogen.cpp
    src/libANGLE/renderer/renderer_utils.cpp
    src/libANGLE/validationEGL.cpp
    src/libANGLE/validationES.cpp
    src/libANGLE/validationES1.cpp
    src/libANGLE/validationES2.cpp
    src/libANGLE/validationES3.cpp
    src/libANGLE/validationES31.cpp
    src/libANGLE/validationES32.cpp
    src/libANGLE/validationESEXT.cpp
)

file(GLOB LIBANGLE_NULL_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE/renderer/null/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE/renderer/null/*.h
)

add_library(angle_libangle STATIC
    ${LIBANGLE_SOURCES}
    ${LIBANGLE_NULL_SOURCES}
    ${CMAKE_CURRENT_LIST_DIR}/compression_utils_portable.cpp
)

target_include_directories(angle_libangle
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/common/base>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    PRIVATE
        ${CMAKE_CURRENT_LIST_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE/renderer
        ${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE/renderer/null
)

target_compile_definitions(angle_libangle
    PUBLIC
        LIBANGLE_IMPLEMENTATION
        ANGLE_ENABLE_CONTEXT_MUTEX=1
        ANGLE_ENABLE_SHARE_CONTEXT_LOCK=1
        ANGLE_CAPTURE_ENABLED=0
        ANGLE_ENABLE_D3D9=0
        ANGLE_ENABLE_D3D11=0
        ANGLE_ENABLE_VULKAN=0
        ANGLE_ENABLE_METAL=0
        ANGLE_ENABLE_OPENGL=0
        ANGLE_ENABLE_NULL=1
        ANGLE_ENABLE_CL=0
)

target_link_libraries(angle_libangle
    PUBLIC
        angle_common
        angle_image_util
        angle_gpu_info_util
        angle_translator
        ZLIB::ZLIB
)

# Windows needs synchronization.lib for WaitOnAddress and WakeByAddressSingle
if(WIN32)
    target_link_libraries(angle_libangle PRIVATE synchronization)
endif()

# ============================================================================
# Real libGLESv2 + libEGL entry points (Null backend wired through libANGLE)
# Split the EGL entry points from GLES to avoid missing symbol resolution
# ============================================================================
set(LIBEGL_ENTRY_SOURCES
    src/libEGL/egl_loader_autogen.cpp
    src/libEGL/egl_loader_autogen.h
    src/libEGL/libEGL_autogen.cpp
    src/libEGL/resource.h
    src/libGLESv2/egl_context_lock_autogen.h
    src/libGLESv2/egl_context_lock_impl.h
    src/libGLESv2/egl_ext_stubs.cpp
    src/libGLESv2/egl_ext_stubs_autogen.h
    src/libGLESv2/egl_stubs.cpp
    src/libGLESv2/egl_stubs_autogen.h
    src/libGLESv2/egl_stubs_getprocaddress_autogen.cpp
    src/libGLESv2/entry_points_egl_autogen.cpp
    src/libGLESv2/entry_points_egl_autogen.h
    src/libGLESv2/entry_points_egl_ext_autogen.cpp
    src/libGLESv2/entry_points_egl_ext_autogen.h
)

set(LIBGLESV2_ENTRY_SOURCES
    src/libGLESv2/entry_points_gles_1_0_autogen.cpp
    src/libGLESv2/entry_points_gles_1_0_autogen.h
    src/libGLESv2/entry_points_gles_2_0_autogen.cpp
    src/libGLESv2/entry_points_gles_2_0_autogen.h
    src/libGLESv2/entry_points_gles_3_0_autogen.cpp
    src/libGLESv2/entry_points_gles_3_0_autogen.h
    src/libGLESv2/entry_points_gles_3_1_autogen.cpp
    src/libGLESv2/entry_points_gles_3_1_autogen.h
    src/libGLESv2/entry_points_gles_3_2_autogen.cpp
    src/libGLESv2/entry_points_gles_3_2_autogen.h
    src/libGLESv2/entry_points_gles_ext_autogen.cpp
    src/libGLESv2/entry_points_gles_ext_autogen.h
    src/libGLESv2/global_state.cpp
    src/libGLESv2/global_state.h
    src/libGLESv2/resource.h
    src/libGLESv2/libGLESv2_autogen.cpp
)

# libEGL and libGLESv2 - Build as DLLs on native Windows, static elsewhere (including Emscripten)
if(WIN32 AND NOT EMSCRIPTEN)
    set(ANGLE_API_LIBRARY_TYPE SHARED)
else()
    set(ANGLE_API_LIBRARY_TYPE STATIC)
endif()

add_library(angle_egl ${ANGLE_API_LIBRARY_TYPE}
    ${LIBEGL_ENTRY_SOURCES}
)

add_library(angle_gles ${ANGLE_API_LIBRARY_TYPE}
    ${LIBGLESV2_ENTRY_SOURCES}
)

# Configure angle_common library
target_include_directories(angle_common
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/common/base>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/src/common/third_party/xxhash
)

target_compile_definitions(angle_common
    PUBLIC
        ANGLE_ENABLE_SHARE_CONTEXT_LOCK=1
        ANGLE_ENABLE_CONTEXT_MUTEX=1
)

target_link_libraries(angle_common
    PUBLIC
        ZLIB::ZLIB
)

# Windows needs synchronization.lib for WaitOnAddress and WakeByAddressSingle
if(WIN32)
    target_link_libraries(angle_common PRIVATE synchronization)
endif()

# Configure angle_egl library
target_include_directories(angle_egl
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/common/base>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(angle_egl
    PUBLIC
        angle_libangle
        angle_common
        ZLIB::ZLIB
)
target_compile_definitions(angle_egl PRIVATE
    LIBANGLE_IMPLEMENTATION
    LIBEGL_IMPLEMENTATION
)

# Configure angle_gles library
target_include_directories(angle_gles
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/common/base>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(angle_gles
    PUBLIC
        angle_libangle
        angle_common
        ZLIB::ZLIB
)
target_compile_definitions(angle_gles PRIVATE
    LIBANGLE_IMPLEMENTATION
    LIBGLESV2_IMPLEMENTATION
)

# Set library properties
set_target_properties(angle_common PROPERTIES
    OUTPUT_NAME "angle_common"
)

set_target_properties(angle_libangle PROPERTIES
    OUTPUT_NAME "libANGLE"
)

set_target_properties(angle_egl PROPERTIES
    OUTPUT_NAME "EGL"
)

set_target_properties(angle_gles PROPERTIES
    OUTPUT_NAME "GLESv2"
)

# Installation
install(TARGETS angle_common angle_image_util angle_gpu_info_util angle_translator angle_libangle angle_egl angle_gles
    EXPORT angle-config
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

install(EXPORT angle-config
    DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/angle
    NAMESPACE angle::
)

# Do not install headers - they are provided by egl-registry and opengl-registry dependencies

# Note: This is an expanded demonstration build that includes EGL and GLES libraries.
# Provides:
# - angle::angle_common - Core utilities
# - angle::angle_egl - EGL API entry points  
# - angle::angle_gles - OpenGL ES API entry points
#
# A complete ANGLE implementation would additionally require:
# 1. Full libANGLE library with renderer backends (src/libGLESv2.gni - 695 lines)
# 2. Shader compiler library (src/compiler.gni - 478 lines)
# 3. Platform-specific backend selection (D3D11/Vulkan/Metal/OpenGL)
# 4. Complete API validation and state tracking
#
# See the referenced GN build files for the complete source list:
# - src/libGLESv2.gni (main library sources)
# - src/compiler.gni (shader compiler sources)
# - src/libANGLE/renderer/*/BUILD.gn (backend-specific sources)
