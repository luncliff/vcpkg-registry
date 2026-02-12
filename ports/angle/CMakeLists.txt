cmake_minimum_required(VERSION 3.15)
project(angle LANGUAGES CXX C)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(APPLE)
    enable_language(OBJCXX)
    set(CMAKE_OBJCXX_STANDARD 17)
endif()

include(GNUInstallDirs)


# Backend options
option(ANGLE_ENABLE_VULKAN "Enable Vulkan backend" OFF)

# Find dependencies
# Use CONFIG mode for vcpkg compatibility (especially on Emscripten)
find_package(ZLIB CONFIG REQUIRED)
find_package(SPIRV-Headers CONFIG REQUIRED)
find_package(SPIRV-Tools CONFIG REQUIRED) # SPIRV-Tools-static
if(ANGLE_ENABLE_VULKAN)
    find_package(Vulkan REQUIRED) # Vulkan::Headers
    find_package(VulkanMemoryAllocator CONFIG REQUIRED) # GPUOpen::VulkanMemoryAllocator
endif()

# Common definitions
add_compile_definitions(
    KHRONOS_STATIC # turn off KHRONOS_APICALL declspec, attributes, imports, etc.
    # GL_GLES_PROTOTYPES=1
    # EGL_EGL_PROTOTYPES=1
    # TODO: testing ANGLE internal declarations
    # GL_GLEXT_PROTOTYPES
    # EGL_EGLEXT_PROTOTYPES
)

# Automatic ANGLE_PLATFORM_* defined in src/common/platform.h
if(WIN32)
    # todo: support ANGLE_ENABLE_WINDOWS_UWP?
    add_compile_definitions(
        WIN32_LEAN_AND_MEAN
        NOMINMAX
    )
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
    src/common/angle_version_info.cpp
    src/common/base/anglebase/sha1.cc
    src/common/debug.cpp
    src/common/entry_points_enum_autogen.cpp
    src/common/event_tracer.cpp
    src/common/CompiledShaderState.cpp
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
if(ANGLE_ENABLE_VULKAN)
    target_sources(angle_common PRIVATE
        src/common/vulkan/vulkan_icd.h
        src/common/vulkan/vulkan_icd.cpp
        src/common/vulkan/libvulkan_loader.cpp
        src/common/vulkan/libvulkan_loader.h
    )
    target_compile_definitions(angle_common PRIVATE
        ANGLE_VK_MOCK_ICD_JSON="VkICD_mock_icd.json"
    )
endif()

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
if(APPLE)
    target_sources(angle_gpu_info_util PRIVATE
        # src/gpu_info_util/SystemInfo_ios.cpp
        # src/gpu_info_util/SystemInfo_macos.mm
        src/gpu_info_util/SystemInfo_apple.mm
    )
endif()
if(ANGLE_ENABLE_VULKAN)
    target_sources(angle_gpu_info_util PRIVATE
        src/gpu_info_util/SystemInfo_vulkan.cpp
        src/gpu_info_util/SystemInfo_vulkan.h
    )
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
# SPIRV utilities - SPIRV instruction building and parsing
# ==============================================================================
add_library(angle_spirv_headers INTERFACE)
target_include_directories(angle_spirv_headers
    INTERFACE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/common/spirv>
        $<INSTALL_INTERFACE:include>
)

add_library(angle_spirv_base STATIC)
target_sources(angle_spirv_base PRIVATE
    src/common/spirv/angle_spirv_utils.cpp
)
target_include_directories(angle_spirv_base
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/common/base>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/common/spirv
)
target_link_libraries(angle_spirv_base
    PUBLIC
        angle_common
        angle_spirv_headers
        SPIRV-Headers::SPIRV-Headers
        SPIRV-Tools-static
)
target_compile_definitions(angle_spirv_base PRIVATE
    LIBANGLE_IMPLEMENTATION
)

add_library(angle_spirv_builder STATIC)
target_sources(angle_spirv_builder PRIVATE
    src/common/spirv/spirv_instruction_builder_autogen.cpp
)
target_include_directories(angle_spirv_builder
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/common/base>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/common/spirv
)
target_link_libraries(angle_spirv_builder
    PUBLIC
        angle_spirv_base
    PRIVATE
        SPIRV-Headers::SPIRV-Headers
)
target_compile_definitions(angle_spirv_builder PRIVATE
    LIBANGLE_IMPLEMENTATION
)

add_library(angle_spirv_parser STATIC)
target_sources(angle_spirv_parser PRIVATE
    src/common/spirv/spirv_instruction_parser_autogen.cpp
)
target_include_directories(angle_spirv_parser
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/common/base>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/common/spirv
)
target_link_libraries(angle_spirv_parser
    PUBLIC
        angle_spirv_base
    PRIVATE
        SPIRV-Headers::SPIRV-Headers
)
target_compile_definitions(angle_spirv_parser PRIVATE
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

file(GLOB PREPROCESSOR_SOURCES
    "src/compiler/preprocessor/*.cpp"
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

target_sources(angle_translator PRIVATE ${TRANSLATOR_SOURCES} ${PREPROCESSOR_SOURCES})

target_include_directories(angle_translator
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/preprocessor
        ${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/translator
)
target_link_libraries(angle_translator PRIVATE
    angle_common
    angle_spirv_builder
    angle_spirv_parser
)
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
    src/libANGLE/capture/FrameCapture_mock.cpp
    src/libANGLE/capture/serialize_mock.cpp
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

set(LIBANGLE_D3D_SHARED_SOURCES
    src/libANGLE/renderer/d3d/BufferD3D.cpp
    src/libANGLE/renderer/d3d/BufferD3D.h
    src/libANGLE/renderer/d3d/CompilerD3D.cpp
    src/libANGLE/renderer/d3d/CompilerD3D.h
    src/libANGLE/renderer/d3d/ContextD3D.h
    src/libANGLE/renderer/d3d/DisplayD3D.cpp
    src/libANGLE/renderer/d3d/DisplayD3D.h
    src/libANGLE/renderer/d3d/DynamicHLSL.cpp
    src/libANGLE/renderer/d3d/DynamicHLSL.h
    src/libANGLE/renderer/d3d/DynamicImage2DHLSL.cpp
    src/libANGLE/renderer/d3d/DynamicImage2DHLSL.h
    src/libANGLE/renderer/d3d/EGLImageD3D.cpp
    src/libANGLE/renderer/d3d/EGLImageD3D.h
    src/libANGLE/renderer/d3d/FramebufferD3D.cpp
    src/libANGLE/renderer/d3d/FramebufferD3D.h
    src/libANGLE/renderer/d3d/HLSLCompiler.cpp
    src/libANGLE/renderer/d3d/HLSLCompiler.h
    src/libANGLE/renderer/d3d/ImageD3D.cpp
    src/libANGLE/renderer/d3d/ImageD3D.h
    src/libANGLE/renderer/d3d/IndexBuffer.cpp
    src/libANGLE/renderer/d3d/IndexBuffer.h
    src/libANGLE/renderer/d3d/IndexDataManager.cpp
    src/libANGLE/renderer/d3d/IndexDataManager.h
    src/libANGLE/renderer/d3d/NativeWindowD3D.cpp
    src/libANGLE/renderer/d3d/NativeWindowD3D.h
    src/libANGLE/renderer/d3d/ProgramD3D.cpp
    src/libANGLE/renderer/d3d/ProgramD3D.h
    src/libANGLE/renderer/d3d/ProgramExecutableD3D.cpp
    src/libANGLE/renderer/d3d/ProgramExecutableD3D.h
    src/libANGLE/renderer/d3d/RenderTargetD3D.cpp
    src/libANGLE/renderer/d3d/RenderTargetD3D.h
    src/libANGLE/renderer/d3d/RenderbufferD3D.cpp
    src/libANGLE/renderer/d3d/RenderbufferD3D.h
    src/libANGLE/renderer/d3d/RendererD3D.cpp
    src/libANGLE/renderer/d3d/RendererD3D.h
    src/libANGLE/renderer/d3d/SamplerD3D.h
    src/libANGLE/renderer/d3d/ShaderD3D.cpp
    src/libANGLE/renderer/d3d/ShaderD3D.h
    src/libANGLE/renderer/d3d/ShaderExecutableD3D.cpp
    src/libANGLE/renderer/d3d/ShaderExecutableD3D.h
    src/libANGLE/renderer/d3d/SurfaceD3D.cpp
    src/libANGLE/renderer/d3d/SurfaceD3D.h
    src/libANGLE/renderer/d3d/SwapChainD3D.cpp
    src/libANGLE/renderer/d3d/SwapChainD3D.h
    src/libANGLE/renderer/d3d/TextureD3D.cpp
    src/libANGLE/renderer/d3d/TextureD3D.h
    src/libANGLE/renderer/d3d/TextureStorage.h
    src/libANGLE/renderer/d3d/VertexBuffer.cpp
    src/libANGLE/renderer/d3d/VertexBuffer.h
    src/libANGLE/renderer/d3d/VertexDataManager.cpp
    src/libANGLE/renderer/d3d/VertexDataManager.h
    src/libANGLE/renderer/d3d/driver_utils_d3d.cpp
    src/libANGLE/renderer/d3d/driver_utils_d3d.h
    src/libANGLE/renderer/d3d/formatutilsD3D.h
)

set(LIBANGLE_D3D11_SOURCES
    src/libANGLE/renderer/d3d/d3d11/Blit11.cpp
    src/libANGLE/renderer/d3d/d3d11/Blit11.h
    src/libANGLE/renderer/d3d/d3d11/Blit11Helper_autogen.inc
    src/libANGLE/renderer/d3d/d3d11/Buffer11.cpp
    src/libANGLE/renderer/d3d/d3d11/Buffer11.h
    src/libANGLE/renderer/d3d/d3d11/Clear11.cpp
    src/libANGLE/renderer/d3d/d3d11/Clear11.h
    src/libANGLE/renderer/d3d/d3d11/Context11.cpp
    src/libANGLE/renderer/d3d/d3d11/Context11.h
    src/libANGLE/renderer/d3d/d3d11/DebugAnnotator11.cpp
    src/libANGLE/renderer/d3d/d3d11/DebugAnnotator11.h
    src/libANGLE/renderer/d3d/d3d11/Device11.cpp
    src/libANGLE/renderer/d3d/d3d11/Device11.h
    src/libANGLE/renderer/d3d/d3d11/ExternalImageSiblingImpl11.cpp
    src/libANGLE/renderer/d3d/d3d11/ExternalImageSiblingImpl11.h
    src/libANGLE/renderer/d3d/d3d11/Fence11.cpp
    src/libANGLE/renderer/d3d/d3d11/Fence11.h
    src/libANGLE/renderer/d3d/d3d11/Framebuffer11.cpp
    src/libANGLE/renderer/d3d/d3d11/Framebuffer11.h
    src/libANGLE/renderer/d3d/d3d11/Image11.cpp
    src/libANGLE/renderer/d3d/d3d11/Image11.h
    src/libANGLE/renderer/d3d/d3d11/IndexBuffer11.cpp
    src/libANGLE/renderer/d3d/d3d11/IndexBuffer11.h
    src/libANGLE/renderer/d3d/d3d11/InputLayoutCache.cpp
    src/libANGLE/renderer/d3d/d3d11/InputLayoutCache.h
    src/libANGLE/renderer/d3d/d3d11/MappedSubresourceVerifier11.cpp
    src/libANGLE/renderer/d3d/d3d11/MappedSubresourceVerifier11.h
    src/libANGLE/renderer/d3d/d3d11/NativeWindow11.h
    src/libANGLE/renderer/d3d/d3d11/PixelTransfer11.cpp
    src/libANGLE/renderer/d3d/d3d11/PixelTransfer11.h
    src/libANGLE/renderer/d3d/d3d11/Program11.cpp
    src/libANGLE/renderer/d3d/d3d11/Program11.h
    src/libANGLE/renderer/d3d/d3d11/ProgramPipeline11.cpp
    src/libANGLE/renderer/d3d/d3d11/ProgramPipeline11.h
    src/libANGLE/renderer/d3d/d3d11/Query11.cpp
    src/libANGLE/renderer/d3d/d3d11/Query11.h
    src/libANGLE/renderer/d3d/d3d11/RenderStateCache.cpp
    src/libANGLE/renderer/d3d/d3d11/RenderStateCache.h
    src/libANGLE/renderer/d3d/d3d11/RenderTarget11.cpp
    src/libANGLE/renderer/d3d/d3d11/RenderTarget11.h
    src/libANGLE/renderer/d3d/d3d11/Renderer11.cpp
    src/libANGLE/renderer/d3d/d3d11/Renderer11.h
    src/libANGLE/renderer/d3d/d3d11/ResourceManager11.cpp
    src/libANGLE/renderer/d3d/d3d11/ResourceManager11.h
    src/libANGLE/renderer/d3d/d3d11/ShaderExecutable11.cpp
    src/libANGLE/renderer/d3d/d3d11/ShaderExecutable11.h
    src/libANGLE/renderer/d3d/d3d11/StateManager11.cpp
    src/libANGLE/renderer/d3d/d3d11/StateManager11.h
    src/libANGLE/renderer/d3d/d3d11/StreamProducerD3DTexture.cpp
    src/libANGLE/renderer/d3d/d3d11/StreamProducerD3DTexture.h
    src/libANGLE/renderer/d3d/d3d11/SwapChain11.cpp
    src/libANGLE/renderer/d3d/d3d11/SwapChain11.h
    src/libANGLE/renderer/d3d/d3d11/TextureStorage11.cpp
    src/libANGLE/renderer/d3d/d3d11/TextureStorage11.h
    src/libANGLE/renderer/d3d/d3d11/TransformFeedback11.cpp
    src/libANGLE/renderer/d3d/d3d11/TransformFeedback11.h
    src/libANGLE/renderer/d3d/d3d11/Trim11.cpp
    src/libANGLE/renderer/d3d/d3d11/Trim11.h
    src/libANGLE/renderer/d3d/d3d11/VertexArray11.cpp
    src/libANGLE/renderer/d3d/d3d11/VertexArray11.h
    src/libANGLE/renderer/d3d/d3d11/VertexBuffer11.cpp
    src/libANGLE/renderer/d3d/d3d11/VertexBuffer11.h
    src/libANGLE/renderer/d3d/d3d11/formatutils11.cpp
    src/libANGLE/renderer/d3d/d3d11/formatutils11.h
    src/libANGLE/renderer/d3d/d3d11/renderer11_utils.cpp
    src/libANGLE/renderer/d3d/d3d11/renderer11_utils.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/buffertotexture11_gs.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/buffertotexture11_ps_4f.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/buffertotexture11_ps_4i.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/buffertotexture11_ps_4ui.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/buffertotexture11_vs.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clear11multiviewgs.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clear11multiviewvs.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clear11vs.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/cleardepth11ps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearfloat11ps1.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearfloat11ps2.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearfloat11ps3.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearfloat11ps4.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearfloat11ps5.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearfloat11ps6.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearfloat11ps7.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearfloat11ps8.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearsint11ps1.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearsint11ps2.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearsint11ps3.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearsint11ps4.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearsint11ps5.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearsint11ps6.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearsint11ps7.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearsint11ps8.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearuint11ps1.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearuint11ps2.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearuint11ps3.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearuint11ps4.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearuint11ps5.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearuint11ps6.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearuint11ps7.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/clearuint11ps8.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/passthrough2d11vs.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/passthrough3d11gs.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/passthrough3d11vs.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/passthroughdepth2d11ps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/passthroughrgba2dms11ps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/resolvecolor2dps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/resolvedepth11_ps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/resolvedepthstencil11_ps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/resolvedepthstencil11_vs.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/resolvestencil11_ps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/swizzlef2darrayps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/swizzlef2dps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/swizzlef3dps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/swizzlei2darrayps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/swizzlei2dps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/swizzlei3dps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/swizzleui2darrayps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/swizzleui2dps.h
    src/libANGLE/renderer/d3d/d3d11/shaders/compiled/swizzleui3dps.h
    src/libANGLE/renderer/d3d/d3d11/texture_format_table_autogen.cpp
    src/libANGLE/renderer/d3d/d3d11/texture_format_table.cpp
    src/libANGLE/renderer/d3d/d3d11/texture_format_table.h
    src/libANGLE/renderer/d3d/d3d11/texture_format_table_utils.h
    src/libANGLE/renderer/d3d/d3d11/win32/NativeWindow11Win32.cpp
    src/libANGLE/renderer/d3d/d3d11/win32/NativeWindow11Win32.h
)

file(GLOB LIBANGLE_D3D11_BLIT_SHADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE/renderer/d3d/d3d11/shaders/compiled/passthrough*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE/renderer/d3d/d3d11/shaders/compiled/multiplyalpha_*.h
)

# D3D9 backend sources (Windows desktop fallback)
set(LIBANGLE_D3D9_SOURCES
    src/libANGLE/renderer/d3d/d3d9/Blit9.cpp
    src/libANGLE/renderer/d3d/d3d9/Blit9.h
    src/libANGLE/renderer/d3d/d3d9/Buffer9.cpp
    src/libANGLE/renderer/d3d/d3d9/Buffer9.h
    src/libANGLE/renderer/d3d/d3d9/Context9.cpp
    src/libANGLE/renderer/d3d/d3d9/Context9.h
    src/libANGLE/renderer/d3d/d3d9/DebugAnnotator9.cpp
    src/libANGLE/renderer/d3d/d3d9/DebugAnnotator9.h
    src/libANGLE/renderer/d3d/d3d9/Device9.cpp
    src/libANGLE/renderer/d3d/d3d9/Device9.h
    src/libANGLE/renderer/d3d/d3d9/Fence9.cpp
    src/libANGLE/renderer/d3d/d3d9/Fence9.h
    src/libANGLE/renderer/d3d/d3d9/Framebuffer9.cpp
    src/libANGLE/renderer/d3d/d3d9/Framebuffer9.h
    src/libANGLE/renderer/d3d/d3d9/Image9.cpp
    src/libANGLE/renderer/d3d/d3d9/Image9.h
    src/libANGLE/renderer/d3d/d3d9/IndexBuffer9.cpp
    src/libANGLE/renderer/d3d/d3d9/IndexBuffer9.h
    src/libANGLE/renderer/d3d/d3d9/NativeWindow9.cpp
    src/libANGLE/renderer/d3d/d3d9/NativeWindow9.h
    src/libANGLE/renderer/d3d/d3d9/Query9.cpp
    src/libANGLE/renderer/d3d/d3d9/Query9.h
    src/libANGLE/renderer/d3d/d3d9/RenderTarget9.cpp
    src/libANGLE/renderer/d3d/d3d9/RenderTarget9.h
    src/libANGLE/renderer/d3d/d3d9/Renderer9.cpp
    src/libANGLE/renderer/d3d/d3d9/Renderer9.h
    src/libANGLE/renderer/d3d/d3d9/ShaderCache.h
    src/libANGLE/renderer/d3d/d3d9/ShaderExecutable9.cpp
    src/libANGLE/renderer/d3d/d3d9/ShaderExecutable9.h
    src/libANGLE/renderer/d3d/d3d9/StateManager9.cpp
    src/libANGLE/renderer/d3d/d3d9/StateManager9.h
    src/libANGLE/renderer/d3d/d3d9/SwapChain9.cpp
    src/libANGLE/renderer/d3d/d3d9/SwapChain9.h
    src/libANGLE/renderer/d3d/d3d9/TextureStorage9.cpp
    src/libANGLE/renderer/d3d/d3d9/TextureStorage9.h
    src/libANGLE/renderer/d3d/d3d9/VertexArray9.h
    src/libANGLE/renderer/d3d/d3d9/VertexBuffer9.cpp
    src/libANGLE/renderer/d3d/d3d9/VertexBuffer9.h
    src/libANGLE/renderer/d3d/d3d9/VertexDeclarationCache.cpp
    src/libANGLE/renderer/d3d/d3d9/VertexDeclarationCache.h
    src/libANGLE/renderer/d3d/d3d9/formatutils9.cpp
    src/libANGLE/renderer/d3d/d3d9/formatutils9.h
    src/libANGLE/renderer/d3d/d3d9/renderer9_utils.cpp
    src/libANGLE/renderer/d3d/d3d9/renderer9_utils.h
    src/libANGLE/renderer/d3d/d3d9/vertexconversion.h
    src/libANGLE/renderer/d3d/d3d9/shaders/compiled/componentmaskpremultps.h
    src/libANGLE/renderer/d3d/d3d9/shaders/compiled/componentmaskps.h
    src/libANGLE/renderer/d3d/d3d9/shaders/compiled/componentmaskunmultps.h
    src/libANGLE/renderer/d3d/d3d9/shaders/compiled/luminancepremultps.h
    src/libANGLE/renderer/d3d/d3d9/shaders/compiled/luminanceps.h
    src/libANGLE/renderer/d3d/d3d9/shaders/compiled/luminanceunmultps.h
    src/libANGLE/renderer/d3d/d3d9/shaders/compiled/passthroughps.h
    src/libANGLE/renderer/d3d/d3d9/shaders/compiled/standardvs.h
)

# ==============================================================================
# Vulkan backend sources (Windows + Linux)
# ==============================================================================
set(LIBANGLE_VULKAN_SOURCES
    src/libANGLE/renderer/vulkan/AllocatorHelperPool.cpp
    src/libANGLE/renderer/vulkan/AllocatorHelperPool.h
    src/libANGLE/renderer/vulkan/BufferVk.cpp
    src/libANGLE/renderer/vulkan/BufferVk.h
    src/libANGLE/renderer/vulkan/CommandQueue.cpp
    src/libANGLE/renderer/vulkan/CommandQueue.h
    src/libANGLE/renderer/vulkan/CompilerVk.cpp
    src/libANGLE/renderer/vulkan/CompilerVk.h
    src/libANGLE/renderer/vulkan/ContextVk.cpp
    src/libANGLE/renderer/vulkan/ContextVk.h
    src/libANGLE/renderer/vulkan/DebugAnnotatorVk.cpp
    src/libANGLE/renderer/vulkan/DebugAnnotatorVk.h
    src/libANGLE/renderer/vulkan/DeviceVk.cpp
    src/libANGLE/renderer/vulkan/DeviceVk.h
    src/libANGLE/renderer/vulkan/DisplayVk.cpp
    src/libANGLE/renderer/vulkan/DisplayVk.h
    src/libANGLE/renderer/vulkan/DisplayVk_api.h
    src/libANGLE/renderer/vulkan/FenceNVVk.cpp
    src/libANGLE/renderer/vulkan/FenceNVVk.h
    src/libANGLE/renderer/vulkan/FramebufferVk.cpp
    src/libANGLE/renderer/vulkan/FramebufferVk.h
    src/libANGLE/renderer/vulkan/ImageVk.cpp
    src/libANGLE/renderer/vulkan/ImageVk.h
    src/libANGLE/renderer/vulkan/MemoryObjectVk.cpp
    src/libANGLE/renderer/vulkan/MemoryObjectVk.h
    src/libANGLE/renderer/vulkan/MemoryTracking.cpp
    src/libANGLE/renderer/vulkan/MemoryTracking.h
    src/libANGLE/renderer/vulkan/OverlayVk.cpp
    src/libANGLE/renderer/vulkan/OverlayVk.h
    src/libANGLE/renderer/vulkan/PersistentCommandPool.cpp
    src/libANGLE/renderer/vulkan/PersistentCommandPool.h
    src/libANGLE/renderer/vulkan/ProgramExecutableVk.cpp
    src/libANGLE/renderer/vulkan/ProgramExecutableVk.h
    src/libANGLE/renderer/vulkan/ProgramPipelineVk.cpp
    src/libANGLE/renderer/vulkan/ProgramPipelineVk.h
    src/libANGLE/renderer/vulkan/ProgramVk.cpp
    src/libANGLE/renderer/vulkan/ProgramVk.h
    src/libANGLE/renderer/vulkan/QueryVk.cpp
    src/libANGLE/renderer/vulkan/QueryVk.h
    src/libANGLE/renderer/vulkan/RenderTargetVk.cpp
    src/libANGLE/renderer/vulkan/RenderTargetVk.h
    src/libANGLE/renderer/vulkan/RenderbufferVk.cpp
    src/libANGLE/renderer/vulkan/RenderbufferVk.h
    src/libANGLE/renderer/vulkan/SamplerVk.cpp
    src/libANGLE/renderer/vulkan/SamplerVk.h
    src/libANGLE/renderer/vulkan/SecondaryCommandBuffer.cpp
    src/libANGLE/renderer/vulkan/SecondaryCommandBuffer.h
    src/libANGLE/renderer/vulkan/SecondaryCommandPool.cpp
    src/libANGLE/renderer/vulkan/SecondaryCommandPool.h
    src/libANGLE/renderer/vulkan/SemaphoreVk.cpp
    src/libANGLE/renderer/vulkan/SemaphoreVk.h
    src/libANGLE/renderer/vulkan/ShaderInterfaceVariableInfoMap.cpp
    src/libANGLE/renderer/vulkan/ShaderInterfaceVariableInfoMap.h
    src/libANGLE/renderer/vulkan/ShaderVk.cpp
    src/libANGLE/renderer/vulkan/ShaderVk.h
    src/libANGLE/renderer/vulkan/ShareGroupVk.cpp
    src/libANGLE/renderer/vulkan/ShareGroupVk.h
    src/libANGLE/renderer/vulkan/Suballocation.cpp
    src/libANGLE/renderer/vulkan/Suballocation.h
    src/libANGLE/renderer/vulkan/SurfaceVk.cpp
    src/libANGLE/renderer/vulkan/SurfaceVk.h
    src/libANGLE/renderer/vulkan/SyncVk.cpp
    src/libANGLE/renderer/vulkan/SyncVk.h
    src/libANGLE/renderer/vulkan/TextureVk.cpp
    src/libANGLE/renderer/vulkan/TextureVk.h
    src/libANGLE/renderer/vulkan/TransformFeedbackVk.cpp
    src/libANGLE/renderer/vulkan/TransformFeedbackVk.h
    src/libANGLE/renderer/vulkan/UtilsVk.cpp
    src/libANGLE/renderer/vulkan/UtilsVk.h
    src/libANGLE/renderer/vulkan/VertexArrayVk.cpp
    src/libANGLE/renderer/vulkan/VertexArrayVk.h
    src/libANGLE/renderer/vulkan/VkImageImageSiblingVk.cpp
    src/libANGLE/renderer/vulkan/VkImageImageSiblingVk.h
    src/libANGLE/renderer/vulkan/VulkanSecondaryCommandBuffer.cpp
    src/libANGLE/renderer/vulkan/VulkanSecondaryCommandBuffer.h
    src/libANGLE/renderer/vulkan/spv_utils.cpp
    src/libANGLE/renderer/vulkan/spv_utils.h
    src/libANGLE/renderer/vulkan/vk_barrier_data.cpp
    src/libANGLE/renderer/vulkan/vk_barrier_data.h
    src/libANGLE/renderer/vulkan/vk_cache_utils.cpp
    src/libANGLE/renderer/vulkan/vk_cache_utils.h
    src/libANGLE/renderer/vulkan/vk_caps_utils.cpp
    src/libANGLE/renderer/vulkan/vk_caps_utils.h
    src/libANGLE/renderer/vulkan/vk_command_buffer_utils.h
    src/libANGLE/renderer/vulkan/vk_format_table_autogen.cpp
    src/libANGLE/renderer/vulkan/vk_format_utils.cpp
    src/libANGLE/renderer/vulkan/vk_format_utils.h
    src/libANGLE/renderer/vulkan/android/vk_android_utils.cpp # noop on non-Android platforms
    src/libANGLE/renderer/vulkan/android/vk_android_utils.h
    src/libANGLE/renderer/vulkan/vk_helpers.cpp
    src/libANGLE/renderer/vulkan/vk_helpers.h
    src/libANGLE/renderer/vulkan/vk_internal_shaders_autogen.cpp
    src/libANGLE/renderer/vulkan/vk_internal_shaders_autogen.h
    src/libANGLE/renderer/vulkan/vk_mandatory_format_support_table_autogen.cpp
    src/libANGLE/renderer/vulkan/vk_mem_alloc_wrapper.cpp
    src/libANGLE/renderer/vulkan/vk_mem_alloc_wrapper.h
    src/libANGLE/renderer/vulkan/vk_ref_counted_event.cpp
    src/libANGLE/renderer/vulkan/vk_ref_counted_event.h
    src/libANGLE/renderer/vulkan/vk_renderer.cpp
    src/libANGLE/renderer/vulkan/vk_renderer.h
    src/libANGLE/renderer/vulkan/vk_resource.cpp
    src/libANGLE/renderer/vulkan/vk_resource.h
    src/libANGLE/renderer/vulkan/vk_utils.cpp
    src/libANGLE/renderer/vulkan/vk_utils.h
    src/libANGLE/renderer/vulkan/vk_wrapper.h
)

# Platform-specific Vulkan sources
set(LIBANGLE_VULKAN_WIN32_SOURCES
    src/libANGLE/renderer/vulkan/win32/DisplayVkWin32.cpp
    src/libANGLE/renderer/vulkan/win32/DisplayVkWin32.h
    src/libANGLE/renderer/vulkan/win32/WindowSurfaceVkWin32.cpp
    src/libANGLE/renderer/vulkan/win32/WindowSurfaceVkWin32.h
)

set(LIBANGLE_VULKAN_LINUX_SOURCES
    src/libANGLE/renderer/vulkan/linux/DeviceVkLinux.cpp
    src/libANGLE/renderer/vulkan/linux/DeviceVkLinux.h
    src/libANGLE/renderer/vulkan/linux/DisplayVkLinux.cpp
    src/libANGLE/renderer/vulkan/linux/DisplayVkLinux.h
    src/libANGLE/renderer/vulkan/linux/DisplayVkOffscreen.cpp
    src/libANGLE/renderer/vulkan/linux/DisplayVkOffscreen.h
    src/libANGLE/renderer/vulkan/linux/DmaBufImageSiblingVkLinux.cpp
    src/libANGLE/renderer/vulkan/linux/DmaBufImageSiblingVkLinux.h
    src/libANGLE/renderer/vulkan/linux/display/DisplayVkSimple.cpp
    src/libANGLE/renderer/vulkan/linux/display/DisplayVkSimple.h
    src/libANGLE/renderer/vulkan/linux/display/WindowSurfaceVkSimple.cpp
    src/libANGLE/renderer/vulkan/linux/display/WindowSurfaceVkSimple.h
    src/libANGLE/renderer/vulkan/linux/headless/DisplayVkHeadless.cpp
    src/libANGLE/renderer/vulkan/linux/headless/DisplayVkHeadless.h
    src/libANGLE/renderer/vulkan/linux/headless/WindowSurfaceVkHeadless.cpp
    src/libANGLE/renderer/vulkan/linux/headless/WindowSurfaceVkHeadless.h
)

set(LIBANGLE_PLATFORM_SOURCES "")
if(WIN32)
    list(APPEND LIBANGLE_PLATFORM_SOURCES
        src/libANGLE/renderer/d3d_format.cpp
        ${LIBANGLE_D3D_SHARED_SOURCES}
        ${LIBANGLE_D3D9_SOURCES}
        ${LIBANGLE_D3D11_SOURCES}
        ${LIBANGLE_D3D11_BLIT_SHADERS}
    )
    if(ANGLE_ENABLE_VULKAN)
        add_compile_definitions(VK_USE_PLATFORM_WIN32_KHR)
        list(APPEND LIBANGLE_PLATFORM_SOURCES
            ${LIBANGLE_VULKAN_SOURCES}
            ${LIBANGLE_VULKAN_WIN32_SOURCES}
        )
    endif()
elseif(UNIX AND NOT APPLE)
    if(ANGLE_ENABLE_VULKAN)
        add_compile_definitions(VK_USE_PLATFORM_XLIB_KHR)
        list(APPEND LIBANGLE_PLATFORM_SOURCES
            ${LIBANGLE_VULKAN_SOURCES}
            ${LIBANGLE_VULKAN_LINUX_SOURCES}
        )
    endif()
endif()

file(GLOB LIBANGLE_NULL_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE/renderer/null/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE/renderer/null/*.h
)

# ============================================================================
# D3D autogen: Generate DXGI and D3D11 tables/helpers in PROJECT_BINARY_DIR
# ============================================================================
if(WIN32)
    find_package(Python3 COMPONENTS Interpreter REQUIRED)
    set(ANGLE_RENDERER_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE/renderer")
    set(ANGLE_D3D11_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE/renderer/d3d/d3d11")
    
    # DXGI format/support tables (required by D3D11)
    set(DXGI_AUTOGEN_DIR "${PROJECT_BINARY_DIR}/src/libANGLE/renderer")
    file(MAKE_DIRECTORY "${DXGI_AUTOGEN_DIR}")
    
    add_custom_command(
        OUTPUT "${DXGI_AUTOGEN_DIR}/dxgi_format_map_autogen.cpp"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ANGLE_RENDERER_SRC_DIR}/angle_format.py" "${DXGI_AUTOGEN_DIR}/angle_format.py"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ANGLE_RENDERER_SRC_DIR}/angle_format_map.json" "${DXGI_AUTOGEN_DIR}/angle_format_map.json"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ANGLE_RENDERER_SRC_DIR}/dxgi_format_data.json" "${DXGI_AUTOGEN_DIR}/dxgi_format_data.json"
        COMMAND ${Python3_EXECUTABLE} "${ANGLE_RENDERER_SRC_DIR}/gen_dxgi_format_table.py"
        WORKING_DIRECTORY "${DXGI_AUTOGEN_DIR}"
        DEPENDS
            "${ANGLE_RENDERER_SRC_DIR}/gen_dxgi_format_table.py"
            "${ANGLE_RENDERER_SRC_DIR}/angle_format.py"
            "${ANGLE_RENDERER_SRC_DIR}/angle_format_map.json"
            "${ANGLE_RENDERER_SRC_DIR}/dxgi_format_data.json"
        COMMENT "Generating dxgi_format_map_autogen.cpp"
    )
    
    add_custom_command(
        OUTPUT "${DXGI_AUTOGEN_DIR}/dxgi_support_table_autogen.cpp"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ANGLE_RENDERER_SRC_DIR}/angle_format.py" "${DXGI_AUTOGEN_DIR}/angle_format.py"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ANGLE_RENDERER_SRC_DIR}/angle_format_map.json" "${DXGI_AUTOGEN_DIR}/angle_format_map.json"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ANGLE_RENDERER_SRC_DIR}/dxgi_support_data.json" "${DXGI_AUTOGEN_DIR}/dxgi_support_data.json"
        COMMAND ${Python3_EXECUTABLE} "${ANGLE_RENDERER_SRC_DIR}/gen_dxgi_support_tables.py"
        WORKING_DIRECTORY "${DXGI_AUTOGEN_DIR}"
        DEPENDS
            "${ANGLE_RENDERER_SRC_DIR}/gen_dxgi_support_tables.py"
            "${ANGLE_RENDERER_SRC_DIR}/angle_format.py"
            "${ANGLE_RENDERER_SRC_DIR}/angle_format_map.json"
            "${ANGLE_RENDERER_SRC_DIR}/dxgi_support_data.json"
        COMMENT "Generating dxgi_support_table_autogen.cpp"
    )
    
    # D3D11 autogen helpers
    set(D3D11_AUTOGEN_DIR "${PROJECT_BINARY_DIR}/src/libANGLE/renderer/d3d/d3d11")
    file(MAKE_DIRECTORY "${D3D11_AUTOGEN_DIR}")
    
    add_custom_command(
        OUTPUT "${D3D11_AUTOGEN_DIR}/Blit11Helper_autogen.inc"
        COMMAND ${Python3_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE/renderer/d3d/d3d11/gen_blit11helper.py"
        WORKING_DIRECTORY "${D3D11_AUTOGEN_DIR}"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/libANGLE/renderer/d3d/d3d11/gen_blit11helper.py"
        COMMENT "Generating Blit11Helper_autogen.inc"
    )
    
    add_custom_command(
        OUTPUT "${D3D11_AUTOGEN_DIR}/texture_format_table_autogen.cpp"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ANGLE_RENDERER_SRC_DIR}/angle_format.py" "${DXGI_AUTOGEN_DIR}/angle_format.py"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ANGLE_RENDERER_SRC_DIR}/angle_format_map.json" "${DXGI_AUTOGEN_DIR}/angle_format_map.json"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ANGLE_D3D11_SRC_DIR}/texture_format_data.json" "${D3D11_AUTOGEN_DIR}/texture_format_data.json"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ANGLE_D3D11_SRC_DIR}/texture_format_map.json" "${D3D11_AUTOGEN_DIR}/texture_format_map.json"
        COMMAND ${Python3_EXECUTABLE} "${ANGLE_D3D11_SRC_DIR}/gen_texture_format_table.py"
        WORKING_DIRECTORY "${D3D11_AUTOGEN_DIR}"
        DEPENDS
            "${ANGLE_D3D11_SRC_DIR}/gen_texture_format_table.py"
            "${ANGLE_D3D11_SRC_DIR}/texture_format_data.json"
            "${ANGLE_D3D11_SRC_DIR}/texture_format_map.json"
            "${ANGLE_RENDERER_SRC_DIR}/angle_format.py"
            "${ANGLE_RENDERER_SRC_DIR}/angle_format_map.json"
        COMMENT "Generating texture_format_table_autogen.cpp"
    )
    
    # Add generated files to D3D source lists
    list(APPEND LIBANGLE_D3D11_SOURCES
        "${D3D11_AUTOGEN_DIR}/Blit11Helper_autogen.inc"
        "${D3D11_AUTOGEN_DIR}/texture_format_table_autogen.cpp"
    )
    
    # Remove source-tree autogen references if present (use binary tree instead)
    list(FILTER LIBANGLE_D3D11_SOURCES EXCLUDE REGEX ".*Blit11Helper_autogen\\.inc$")
    list(FILTER LIBANGLE_D3D11_SOURCES EXCLUDE REGEX ".*texture_format_table_autogen\\.cpp$")
endif()

add_library(angle_libangle STATIC
    ${LIBANGLE_SOURCES}
    ${LIBANGLE_NULL_SOURCES}
    ${LIBANGLE_PLATFORM_SOURCES}
    ${CMAKE_CURRENT_LIST_DIR}/compression_utils_portable.cpp
)

# Add DXGI autogen sources on Windows
if(WIN32)
    target_sources(angle_libangle PRIVATE
        "${DXGI_AUTOGEN_DIR}/dxgi_format_map_autogen.cpp"
        "${DXGI_AUTOGEN_DIR}/dxgi_support_table_autogen.cpp"
    )
endif()

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
        $<$<BOOL:${WIN32}>:${PROJECT_BINARY_DIR}/src>
        $<$<BOOL:${WIN32}>:${PROJECT_BINARY_DIR}/src/libANGLE/renderer>
        $<$<BOOL:${WIN32}>:${PROJECT_BINARY_DIR}/src/libANGLE/renderer/d3d/d3d11>
)

target_compile_definitions(angle_libangle
    PUBLIC
        LIBANGLE_IMPLEMENTATION
        ANGLE_ENABLE_CONTEXT_MUTEX=1
        ANGLE_ENABLE_SHARE_CONTEXT_LOCK=1
        ANGLE_CAPTURE_ENABLED=0
        ANGLE_ENABLE_NULL=1
)
if(WIN32)
    target_compile_definitions(angle_libangle
        PUBLIC
            ANGLE_ENABLE_D3D9=1
            ANGLE_ENABLE_D3D11=1
            ANGLE_PRELOADED_D3DCOMPILER_MODULE_NAMES={"d3dcompiler_47.dll","d3dcompiler_46.dll","d3dcompiler_43.dll"}
    )
endif()

target_link_libraries(angle_libangle
    PUBLIC
        angle_common
        angle_image_util
        angle_gpu_info_util
        angle_translator
        angle_spirv_base
        angle_spirv_builder
        angle_spirv_parser
        ZLIB::ZLIB
        SPIRV-Headers::SPIRV-Headers
)

if(ANGLE_ENABLE_VULKAN)
    target_compile_definitions(angle_libangle
        PUBLIC
            ANGLE_ENABLE_VULKAN=1
        PRIVATE
            VMA_IMPLEMENTATION # make the VMA functions part of libangle
    )
    target_link_libraries(angle_libangle PUBLIC
        Vulkan::Vulkan
        GPUOpen::VulkanMemoryAllocator
    )
endif()

# Windows needs synchronization.lib for WaitOnAddress and WakeByAddressSingle
if(WIN32)
    target_link_libraries(angle_libangle PRIVATE synchronization d3d9 d3d11 dxgi d3dcompiler dxguid)
    # Delay-load D3D9 for runtime flexibility (D3D11 is preferred)
    if(MSVC)
        target_link_libraries(angle_libangle PRIVATE delayimp)
        target_link_options(angle_libangle PRIVATE /DELAYLOAD:d3d9.dll)
    endif()
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
    ${LIBGLESV2_ENTRY_SOURCES}
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
    PRIVATE
        angle_libangle
        angle_common
        ZLIB::ZLIB
)
target_compile_definitions(angle_egl PRIVATE
    LIBANGLE_IMPLEMENTATION
    LIBEGL_IMPLEMENTATION
    LIBGLESV2_IMPLEMENTATION
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
    PRIVATE
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
install(TARGETS angle_egl angle_gles
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
