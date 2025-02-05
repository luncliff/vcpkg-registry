if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()
set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled) # there are some python scripts

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggerganov/llama.cpp
    REF "b${VERSION}"
    SHA512 d939bb35e492dba06068e49dd0b28e8352fcbf598c1d7198fdedb405893b4c3a90b3709f0c57e57ffe3e92860d7c5ad21a2cc1129d50c07f27470b8b37d87183
    HEAD_REF master
    PATCHES
        fix-cmake-ggml.patch
)

vcpkg_find_acquire_program(GIT)
message(STATUS "Using git: ${GIT}")

# for BLAS, see https://cmake.org/cmake/help/latest/module/FindBLAS.html#blas-lapack-vendors
vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        server  LLAMA_BUILD_SERVER
        server  LLAMA_BUILD_EXAMPLES
        cuda    LLAMA_CUBLAS
        cuda    GGML_CUDA
        cuda    GGML_CUDA_GRAPHS_DEFAULT
        opencl  GGML_OPENCL
        openmp  GGML_OPENMP
        vulkan  GGML_VULKAN
        vulkan  GGML_VULKAN_CHECK_RESULTS
        # vulkan  GGML_VULKAN_VALIDATE 
)

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC)

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
    list(APPEND ARCH_OPTIONS
        -DGGML_AARCH64=ON
    )
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        ${ARCH_OPTIONS}
        # see cmake/build-info.cmake
        "-DGIT_EXECUTABLE:FILEPATH=${GIT}"
        "-DBUILD_NUMBER=${VERSION}"
        "-DBUILD_COMMIT:STRING=d774ab3acc4fee41fbed6dbfc192b57d5f79f34b"
        # ${SOURCE_PATH}/CMakeLists.txt
        -DLLAMA_STANDALONE=ON
        -DLLAMA_CURL=ON
        -DLLAMA_LLGUIDANCE=OFF
        -DLLAMA_ALL_WARNINGS=OFF
        -DLLAMA_BUILD_TESTS=OFF
        # ${SOURCE_PATH}/ggml/CMakeLists.txt
        -DGGML_STANDALONE=ON
        -DGGML_BUILD_NUMBER=${VERSION}
        -DGGML_LLAMAFILE_DEFAULT=OFF
        -DGGML_FATAL_WARNINGS=OFF
        -DGGML_CPU_ALL_VARIANTS=OFF
        -DGGML_BACKEND_DL=OFF
        -DGGML_METAL_USE_BF16=ON
        -DGGML_METAL_EMBED_LIBRARY=ON
        -DGGML_OPENMP=OFF
        -DGGML_BUILD_TESTS=OFF
        -DGGML_BUILD_EXAMPLES=OFF
    OPTIONS_RELEASE
        -DGGML_METAL_NDEBUG=ON
)
vcpkg_cmake_install()

vcpkg_fixup_pkgconfig()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/ggml" PACKAGE_NAME "ggml" DO_NOT_DELETE_PARENT_CONFIG_PATH)
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/llama" PACKAGE_NAME "llama")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
