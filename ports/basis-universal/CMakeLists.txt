cmake_minimum_required(VERSION 3.13)
project(basisu CXX)

include(GNUInstallDirs)
include(CheckCXXCompilerFlag)
set(CMAKE_CXX_STANDARD 11)

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

if(EMSCRIPTEN)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -s ALLOW_MEMORY_GROWTH=1 -DBASISU_SUPPORT_SSE=0")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -s ALLOW_MEMORY_GROWTH=1 -DBASISU_SUPPORT_SSE=0")
endif()

if(MSVC)
    check_cxx_compiler_flag("/arch:SSE" USE_SSE)

else()
    set(CMAKE_CXX_VISIBILITY_PRESET "default") # use hidden?
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
    add_compile_definitions(
        # -fno-strict-aliasing
        _LARGEFILE64_SOURCE=1
        -D_FILE_OFFSET_BITS=64
    )
    if(CMAKE_SYSTEM_PROCESSOR MATCHES x86)
        check_cxx_compiler_flag("-msse4" USE_SSE4)
        if(USE_SSE4)
            add_compile_options("-msse4")
        endif()
        check_cxx_compiler_flag("-msse4.1" USE_SSE41)
        if(USE_SSE41)
            add_compile_options("-msse4.1")
        endif()
        check_cxx_compiler_flag("-msse4.2" USE_SSE42)
        if(USE_SSE42)
            add_compile_options("-msse4.2")
        endif()
        if(USE_SSE4 OR USE_SSE41 OR USE_SSE42)
            set(USE_SSE ON)
        endif()
    endif()
endif()

if(USE_SSE)
    add_compile_definitions(BASISU_SUPPORT_SSE=1)
else()
    add_compile_definitions(BASISU_SUPPORT_SSE=0)
endif()

list(APPEND ENCODER_SRCS
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
    encoder/basisu_astc_hdr_enc.cpp
	encoder/3rdparty/android_astc_decomp.cpp
    encoder/3rdparty/tinyexr.cpp
)
add_library(basisu_encoder STATIC ${ENCODER_SRCS})

list(APPEND TRANSCODER_SRCS
    transcoder/basisu_transcoder.cpp
)
add_library(basisu_transcoder STATIC ${TRANSCODER_SRCS})
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
