if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()
set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled) # there are some python scripts

# https://github.com/ggml-org/llama.cpp/releases/tag/v${VERSION}
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggml-org/llama.cpp
    REF "v${VERSION}"
    SHA512 d5e204e7983280001e4fba1c4cba2d6b82eca3a628867dcf9c3ff3333fff93d2d416535edeb4baad546979967d0b04c9b35d9728e0ab200d49d832b137cc4a56
    HEAD_REF master
    PATCHES
        fix-3rdparty.patch
        fix-cmake-configs.patch
        fix-opencl-kernel-encoding.patch
)
file(REMOVE_RECURSE
    "${SOURCE_PATH}/vendor/nlohmann" # nlohmann-json
    "${SOURCE_PATH}/vendor/miniaudio" # miniaudio
    "${SOURCE_PATH}/vendor/cpp-httplib" # cpp-httplib
    "${SOURCE_PATH}/vendor/stb" # stb
    "${SOURCE_PATH}/vendor/hash/xxhash" # xxhash
    "${SOURCE_PATH}/vendor/hash/sha1" # SHA-1
    "${SOURCE_PATH}/vendor/hash/sha256" # OpenSSL
)
if(NOT "tools" IN_LIST FEATURES)
    file(REMOVE_RECURSE "${SOURCE_PATH}/vendor/sheredom")
endif()

vcpkg_find_acquire_program(GIT)
message(STATUS "Using git: ${GIT}")

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using python3: ${PYTHON3}")

# for BLAS, see https://cmake.org/cmake/help/latest/module/FindBLAS.html#blas-lapack-vendors
vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tools   LLAMA_BUILD_TOOLS
        tools   LLAMA_BUILD_SERVER
        tools   LLAMA_OPENSSL
        tools   LLAMA_SUBPROCESS
        cuda    GGML_CUDA
        cuda    GGML_CUDA_GRAPHS
        opencl  GGML_OPENCL
        opencl  GGML_OPENCL_EMBED_KERNELS
        openmp  GGML_OPENMP
        metal   GGML_METAL
        metal   GGML_METAL_EMBED_LIBRARY
)

if(VCPKG_TARGET_IS_OSX)
    # compiler flag -mmacosx-version-min
    if(NOT DEFINED VCPKG_CMAKE_SYSTEM_VERSION)
        set(VCPKG_CMAKE_SYSTEM_VERSION 11.0)
    endif()
    list(APPEND FEATURE_OPTIONS
        -DGGML_METAL_MACOSX_VERSION_MIN=${VCPKG_CMAKE_SYSTEM_VERSION}
        -DGGML_METAL_STD=17
    )
endif()

if("cuda" IN_LIST FEATURES)
    vcpkg_find_cuda(OUT_CUDA_TOOLKIT_ROOT cuda_toolkit_root)
    list(APPEND FEATURE_OPTIONS
        "-DCMAKE_CUDA_COMPILER:FILEPATH=${NVCC}"
        "-DCUDAToolkit_ROOT=${cuda_toolkit_root}"
    )
endif()

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    list(APPEND ARCH_OPTIONS
        -DGGML_AVX2=ON
        -DGGML_AVX=ON
        -DGGML_AVX512=ON
        -DGGML_AVX512_VBMI=ON
        -DGGML_AVX512_VNNI=ON
    )
endif()
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    if(VCPKG_TARGET_IS_WINDOWS)
        # ggml-cpu: MSVC is not supported for ARM, use clang
        set(VCPKG_PLATFORM_TOOLSET ClangCL) # see CMAKE_GENERATOR_TOOLSET
        set(GENERATOR_OPTIONS WINDOWS_USE_MSBUILD)
    endif()
endif()

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" BUILD_SHARED)

if(VCPKG_CROSSCOMPILING)
    set(BUILD_NATIVE OFF)
else()
    set(BUILD_NATIVE ON)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    ${GENERATOR_OPTIONS}
    OPTIONS
        ${FEATURE_OPTIONS}
        ${ARCH_OPTIONS}
        # see cmake/build-info.cmake
        "-DGIT_EXECUTABLE:FILEPATH=${GIT}"
        "-DPython3_EXECUTABLE:FILEPATH=${PYTHON3}"
        "-DBUILD_NUMBER:STRING=${VERSION}"
        "-DBUILD_COMMIT:STRING=b${VERSION}"
        # ${SOURCE_PATH}/CMakeLists.txt
        -DLLAMA_STANDALONE=ON
        -DLLAMA_LLGUIDANCE=OFF
        -DLLAMA_ALL_WARNINGS=OFF
        # ${SOURCE_PATH}/ggml/CMakeLists.txt
        -DGGML_STANDALONE=ON
        -DGGML_NATIVE=${BUILD_NATIVE}
        -DGGML_BUILD_NUMBER=${VERSION}
        -DGGML_LLAMAFILE_DEFAULT=OFF
        -DGGML_CPU_ALL_VARIANTS=OFF
        -DGGML_BACKEND_DL=OFF # requires BUILD_SHARED_LIBS
        -DGGML_OPENCL_PROFILING=OFF
        -DGGML_FATAL_WARNINGS=OFF
        # Explicitly disable test/benchmark executables
        -DLLAMA_BUILD_TESTS=OFF
        -DGGML_BUILD_TESTS=OFF
        -DLLAMA_BUILD_EXAMPLES=OFF
        -DGGML_BUILD_EXAMPLES=OFF
        -DLLAMA_BUILD_APP=OFF
    OPTIONS_DEBUG
        -DGGML_METAL_SHADER_DEBUG=ON
    OPTIONS_RELEASE
        -DGGML_METAL_NDEBUG=ON
        -DGGML_METAL_SHADER_DEBUG=OFF
    MAYBE_UNUSED_VARIABLES
        Python3_EXECUTABLE
)
vcpkg_cmake_install()

vcpkg_fixup_pkgconfig()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/ggml" PACKAGE_NAME "ggml" DO_NOT_DELETE_PARENT_CONFIG_PATH)
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/llama" PACKAGE_NAME "llama")

file(COPY "${SOURCE_PATH}/grammars"
          "${SOURCE_PATH}/models"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
if(EXISTS "${SOURCE_PATH}/prompts")
    file(COPY "${SOURCE_PATH}/prompts"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
    )
endif()

if("tools" IN_LIST FEATURES)
    vcpkg_copy_tools(AUTO_CLEAN TOOL_NAMES
        llama-batched-bench
        llama-bench
        llama-cli
        llama-cvector-generator
        llama-export-lora
        llama-gguf-split
        llama-imatrix
        llama-mtmd-cli
        llama-perplexity
        llama-quantize
        llama-results
        llama-server
        llama-tokenize
        llama-tts
        llama-fit-params
        llama-completion
    )
    # file(INSTALL
    #     "${SOURCE_PATH}/examples/chat.sh"
    #     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
    # )
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
