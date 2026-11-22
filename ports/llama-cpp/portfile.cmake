if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ggml-org/llama.cpp
    REF "v${VERSION}"
    SHA512 d5e204e7983280001e4fba1c4cba2d6b82eca3a628867dcf9c3ff3333fff93d2d416535edeb4baad546979967d0b04c9b35d9728e0ab200d49d832b137cc4a56
    HEAD_REF master
    PATCHES
        fix-3rdparty.patch
        fix-llama-cmake-config.patch
)
vcpkg_from_github(
    OUT_SOURCE_PATH GGML_SOURCE_PATH
    REPO ggml-org/ggml
    REF "v${VERSION}"
    SHA512 a5098169d420d84f93389f10a4d558651d38140d8cac88f6007156256e1b18987efb3767d384484c14bc42d00e583a3ee538bdbc1b714ce0c3d58de94dd4b614
    HEAD_REF master
    PATCHES
        fix-ggml-cmake-config.patch
        fix-ggml-opencl-kernel-encoding.patch
)
file(REMOVE_RECURSE "${SOURCE_PATH}/ggml")
file(COPY "${GGML_SOURCE_PATH}/" DESTINATION "${SOURCE_PATH}/ggml")

file(REMOVE_RECURSE
    "${SOURCE_PATH}/vendor/nlohmann" # port: nlohmann-json
    "${SOURCE_PATH}/vendor/miniaudio" # port: miniaudio
    "${SOURCE_PATH}/vendor/cpp-httplib" # port: cpp-httplib
    "${SOURCE_PATH}/vendor/stb" # port: stb
    "${SOURCE_PATH}/vendor/hash/xxhash" # port: xxhash
    "${SOURCE_PATH}/vendor/hash/sha1" # port: openssl?
    "${SOURCE_PATH}/vendor/hash/sha256" # port: openssl
)
if(NOT "tools" IN_LIST FEATURES)
    file(REMOVE_RECURSE "${SOURCE_PATH}/vendor/sheredom")
endif()

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using Python3: ${PYTHON3}")

vcpkg_find_acquire_program(GIT)
message(STATUS "Using git: ${GIT}")

if(VCPKG_TARGET_IS_WINDOWS)
    set(VCPKG_C_FLAGS "${VCPKG_C_FLAGS} /wd4819")
    set(VCPKG_CXX_FLAGS "${VCPKG_CXX_FLAGS} /wd4819")
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        blas    GGML_BLAS
        tools   LLAMA_BUILD_TOOLS
        tools   LLAMA_BUILD_SERVER
        tools   LLAMA_OPENSSL
        tools   LLAMA_SUBPROCESS
        cuda    GGML_CUDA
        llamafile GGML_LLAMAFILE
        opencl  GGML_OPENCL
        openmp  GGML_OPENMP
        openvino GGML_OPENVINO
        rpc     GGML_RPC
        metal   GGML_METAL
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
    if(VCPKG_TARGET_IS_WINDOWS)
        list(APPEND FEATURE_OPTIONS
            "-DCMAKE_CUDA_FLAGS=-Xcompiler=/wd4819"
        )
    endif()
endif()

if("blas" IN_LIST FEATURES)
    list(APPEND FEATURE_OPTIONS
        -DGGML_BLAS_VENDOR=OpenBLAS
        "-DBLAS_INCLUDE_DIRS:PATH=${CURRENT_INSTALLED_DIR}/include/openblas"
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

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    set(GGML_STATIC ON)
else()
    set(GGML_STATIC OFF)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    ${GENERATOR_OPTIONS}
    OPTIONS
        ${FEATURE_OPTIONS}
        ${ARCH_OPTIONS}
        # see cmake/build-info.cmake
        "-DPython3_EXECUTABLE:FILEPATH=${PYTHON3}"
        "-DGIT_EXECUTABLE:FILEPATH=${GIT}"
        "-DBUILD_NUMBER:STRING=${VERSION}"
        "-DBUILD_COMMIT:STRING=b${VERSION}"
        # ${SOURCE_PATH}/CMakeLists.txt
        -DLLAMA_USE_PREBUILT_UI=OFF
        -DLLAMA_ALL_WARNINGS=OFF
        # ${SOURCE_PATH}/ggml/CMakeLists.txt
        -DGGML_STATIC=${GGML_STATIC}
        -DGGML_BUILD_NUMBER=${VERSION}
        -DGGML_BACKEND_DL=OFF
        # Explicitly disable test/benchmark executables
        -DLLAMA_BUILD_TESTS=OFF
        -DLLAMA_BUILD_EXAMPLES=OFF
        -DLLAMA_BUILD_APP=OFF
    OPTIONS_DEBUG
        -DGGML_METAL_SHADER_DEBUG=ON
    OPTIONS_RELEASE
        -DGGML_METAL_NDEBUG=ON
        -DGGML_METAL_SHADER_DEBUG=OFF
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
)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/bin")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
