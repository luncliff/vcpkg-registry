if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()
set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled) # there are some python scripts

# https://github.com/ggml-org/llama.cpp/releases/tag/b5158
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggerganov/llama.cpp
    REF "b${VERSION}"
    SHA512 796e5b641f1cb88f085b6a96d428f363fa32d11c1bc426042fbc266ceab834aa53c510cd1d91f856042c2bc3078f5eda6e27a9341510458859962c0d0c9dabc0
    HEAD_REF master
    PATCHES
        fix-cmake-ggml.patch
        fix-cmake-llama.patch
        fix-3rdparty.patch
)
file(REMOVE
    "${SOURCE_PATH}/common/json.hpp" # nlohmann-json
    "${SOURCE_PATH}/examples/server/httplib.h" # cpp-httplib
)

vcpkg_find_acquire_program(GIT)
message(STATUS "Using git: ${GIT}")

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using python3: ${PYTHON3}")

# for BLAS, see https://cmake.org/cmake/help/latest/module/FindBLAS.html#blas-lapack-vendors
vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        server  LLAMA_BUILD_SERVER
        server  LLAMA_SERVER_SSL
        cuda    GGML_CUDA
        cuda    GGML_CUDA_GRAPHS
        cuda    GGML_CUDA_FORCE_MMQ
        cuda    GGML_CUDA_FORCE_CUBLAS
        cuda    GGML_CUDA_NO_VMM
        cuda    GGML_CUDA_F16
        cuda    GGML_CUDA_DMMV_F16
        cuda    GGML_CUDA_NO_PEER_COPY
        opencl  GGML_OPENCL
        opencl  GGML_OPENCL_EMBED_KERNELS
        openmp  GGML_OPENMP
        vulkan  GGML_VULKAN
        vulkan  GGML_VULKAN_CHECK_RESULTS
        # vulkan  GGML_VULKAN_PERF
        metal   GGML_METAL_USE_BF16
        metal   GGML_METAL_EMBED_LIBRARY
        # todo: support these in native environment?
        test    LLAMA_BUILD_TESTS
        test    GGML_BUILD_TESTS
        example LLAMA_BUILD_EXAMPLES
        example GGML_BUILD_EXAMPLES
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

if("vulkan" IN_LIST FEATURES)
    list(APPEND TOOL_PATHS "${VCPKG_HOST_INSTALLED_DIR}/tools/glslang")
    if(DEFINED ENV{VULKAN_SDK})
        list(APPEND TOOL_PATHS "$ENV{VULKAN_SDK}/Bin")
    endif()
    if(DEFINED ENV{VK_SDK_PATH})
        list(APPEND TOOL_PATHS "$ENV{VK_SDK_PATH}/Bin")
    endif()
    find_program(GLSLC NAMES glslc PATHS ${TOOL_PATHS} REQUIRED)
    message(STATUS "Using glslc: ${GLSLC}")
    find_program(GLSLANG_VALIDATOR NAMES glslangValidator PATHS ${TOOL_PATHS} REQUIRED)
    message(STATUS "Using glslangValidator: ${GLSLANG_VALIDATOR}")
    list(APPEND FEATURE_OPTIONS
        "-DVulkan_GLSLC_EXECUTABLE:FILEPATH=${GLSLC}"
        "-DVulkan_GLSLANG_VALIDATOR_EXECUTABLE=${GLSLANG_VALIDATOR}"
    )
    get_filename_component(GLSL_TOOL_DIR "${GLSLC}" PATH)
    vcpkg_add_to_path(PREPEND "${GLSL_TOOL_DIR}")
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
    list(APPEND ARCH_OPTIONS
        -DGGML_AARCH64=ON
    )
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
        -DLLAMA_CURL=ON
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
    OPTIONS_DEBUG
        -DGGML_VULKAN_DEBUG=ON
        -DGGML_VULKAN_VALIDATE=ON
        -DGGML_VULKAN_MEMORY_DEBUG=ON
        -DGGML_VULKAN_SHADER_DEBUG_INFO=ON
        -DGGML_METAL_SHADER_DEBUG=ON
    OPTIONS_RELEASE
        -DGGML_METAL_NDEBUG=ON
        -DGGML_METAL_SHADER_DEBUG=OFF
    MAYBE_UNUSED_VARIABLES
        LLAMA_SERVER_SSL
        Python3_EXECUTABLE
)
vcpkg_cmake_install()

vcpkg_fixup_pkgconfig()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/ggml" PACKAGE_NAME "ggml" DO_NOT_DELETE_PARENT_CONFIG_PATH)
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/llama" PACKAGE_NAME "llama")

if("server" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES llama-server DESTINATION "${CURRENT_PACKAGES_DIR}/tools/llama.cpp" AUTO_CLEAN)
    file(INSTALL
        "${SOURCE_PATH}/examples/server/public"
        "${SOURCE_PATH}/examples/server/public_simplechat"
        "${SOURCE_PATH}/examples/server/chat.mjs"
        "${SOURCE_PATH}/examples/server/chat.sh"
        "${SOURCE_PATH}/examples/server/chat-llama2.sh"
        "${SOURCE_PATH}/examples/server/README.md"
        DESTINATION "${CURRENT_PACKAGES_DIR}/tools/llama.cpp"
    )
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
