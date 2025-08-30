cmake_minimum_required(VERSION 3.13)
project(basisu CXX)

include(GNUInstallDirs)
include(CheckCXXCompilerFlag)
set(CMAKE_CXX_STANDARD 17)

option(USE_ZSTD "ZSTD support" TRUE)
option(USE_OPENCL "OpenCL support" FALSE)

if(USE_ZSTD)
    find_package(zstd CONFIG REQUIRED) # zstd::libzstd
    add_compile_definitions(BASISD_SUPPORT_KTX2_ZSTD=1)
else()
    add_compile_definitions(BASISD_SUPPORT_KTX2_ZSTD=0)
endif()

if(USE_OPENCL)
   find_package(OpenCL REQUIRED)
   add_compile_definitions(BASISD_SUPPORT_OPENCL=1)
endif()

# Emscripten-specific settings (aligned with upstream)
if(EMSCRIPTEN)
    add_compile_options(-s ALLOW_MEMORY_GROWTH=1)
    add_compile_definitions(BASISU_SUPPORT_SSE=0)
endif()

# Compiler-specific settings (simplified from upstream)
if(MSVC)
    check_cxx_compiler_flag("/arch:SSE" USE_SSE)
    if(USE_SSE)
        add_compile_definitions(BASISU_SUPPORT_SSE=1)
    else()
        add_compile_definitions(BASISU_SUPPORT_SSE=0)
    endif()
else()
    # Non-MSVC settings (GCC/Clang)
    add_compile_definitions(
        _LARGEFILE64_SOURCE=1
        _FILE_OFFSET_BITS=64
    )
    
    # Add upstream's essential compiler flags
    add_compile_options(-fno-strict-aliasing)
    
    # SSE support for x86 architectures
    if(CMAKE_SYSTEM_PROCESSOR MATCHES x86)
        check_cxx_compiler_flag("-msse4.1" USE_SSE41)
        if(USE_SSE41)
            add_compile_options(-msse4.1)
            add_compile_definitions(BASISU_SUPPORT_SSE=1)
            set(USE_SSE ON)
        endif()
    endif()
    
    if(NOT USE_SSE)
        add_compile_definitions(BASISU_SUPPORT_SSE=0)
    endif()
endif()

# Define source files (following upstream structure)
set(ENCODER_LIB_SRC_LIST
    encoder/basisu_backend.cpp
    encoder/basisu_basis_file.cpp
    encoder/basisu_comp.cpp
    encoder/basisu_enc.cpp
    encoder/basisu_etc.cpp
    encoder/basisu_frontend.cpp
    encoder/basisu_gpu_texture.cpp
    encoder/basisu_pvrtc1_4.cpp
    encoder/basisu_resampler.cpp
    encoder/basisu_resample_filters.cpp
    encoder/basisu_ssim.cpp
    encoder/basisu_uastc_enc.cpp
    encoder/basisu_bc7enc.cpp
    encoder/jpgd.cpp
    encoder/basisu_kernels_sse.cpp
    encoder/basisu_opencl.cpp
    encoder/pvpngreader.cpp
    encoder/basisu_uastc_hdr_4x4_enc.cpp
    encoder/basisu_astc_hdr_6x6_enc.cpp
    encoder/basisu_astc_hdr_common.cpp
    encoder/3rdparty/android_astc_decomp.cpp
    encoder/3rdparty/tinyexr.cpp
)

# Create static encoder library (following upstream approach)
add_library(basisu_encoder STATIC ${ENCODER_LIB_SRC_LIST})

# Create separate transcoder library for vcpkg compatibility
set(TRANSCODER_LIB_SRC_LIST
    transcoder/basisu_transcoder.cpp
)
add_library(basisu_transcoder STATIC ${TRANSCODER_LIB_SRC_LIST})
target_link_libraries(basisu_transcoder PUBLIC basisu_encoder)

if(USE_ZSTD)
    target_link_libraries(basisu_encoder PUBLIC zstd::libzstd)
    target_link_libraries(basisu_transcoder PUBLIC zstd::libzstd)
endif()
if(USE_OPENCL)
    target_link_libraries(basisu_encoder PUBLIC OpenCL::OpenCL)
    target_link_libraries(basisu_transcoder PUBLIC OpenCL::OpenCL)
endif()

# install encoder/basisu_*.h headers to ${CMAKE_INSTALL_INCLUDEDIR}/encoder
install(DIRECTORY encoder
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    FILES_MATCHING PATTERN "basisu_*.h"
)

# install transcoder/basisu_*.h headers to ${CMAKE_INSTALL_INCLUDEDIR}/transcoder
install(DIRECTORY transcoder
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    FILES_MATCHING PATTERN "basisu_*.h"
)

install(TARGETS basisu_encoder basisu_transcoder
    # EXPORT basisu-targets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
# install(EXPORT basisu-targets
#     FILE basisu-targets.cmake
#     NAMESPACE basisu::
#     DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/basisu
# )
