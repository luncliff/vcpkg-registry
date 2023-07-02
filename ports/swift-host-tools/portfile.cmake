vcpkg_minimum_required(VERSION 2023-01-24) # https://github.com/microsoft/vcpkg-tool/releases
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

# todo: Xml2, FFI, ZLIB, etc...
set(VCPKG_PREFER_SYSTEM_LIBS ON)

# message(STATUS "Required APT packages")
# message(STATUS "  clang-15 clang-tools-15 llvm-15-dev libclang-15-dev")

vcpkg_from_github(
    OUT_SOURCE_PATH LLVM_STAGING_SOURCE_PATH
    REPO llvm/llvm-project-staging
    REF cc926dc3a87af7023aa9b6c392347a0a8ed6949b
    SHA512 c6d31b859bc7099d3abfda9af97493e1a42afe40cffcb86a76b79d63800ab457048c6d4ffce172e0deefbdf255b03f48d31da545d5a44100926dd8764fbb4067
    HEAD_REF staging/apple
)

vcpkg_from_github(
    OUT_SOURCE_PATH SYNTAX_SOURCE_PATH
    REPO apple/swift-syntax
    REF 508.0.0
    SHA512 91c07a4b2e5b37385f8ac1f6b4ab2d6873e86849eab9fba71cbbc99ceb5dc5870f532eed2ec79eb9cbe3876cd44789fbb60635efc300c1a2265ec1b9bd8abf41
)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/swift
    REF swift-5.8.1-RELEASE
    SHA512 2cc0a34fc4451553acea9be14b56d8e33dfa9f4a65847426f0998113cb42af5cf56acbda7be55b07e3f1a8524af66a98d786f5e8b770cf733159d6b84588d21d
    HEAD_REF main
    PATCHES
        fix-linux-cmake.patch
)

x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES sympy
    OUT_PYTHON_VAR PYTHON3
)
message(STATUS "Using python3: ${PYTHON3}")

find_path(Clang_DIR NAMES ClangConfig.cmake
    PATHS ${CURRENT_INSTALLED_DIR}/lib/cmake/clang
        #   /usr/lib/llvm-15/lib/cmake/clang
        #   /usr/lib/cmake/clang-15
    REQUIRED NO_DEFAULT_PATH
)
message(STATUS "Found ClangConfig.cmake: ${Clang_DIR}")

find_program(CLANG_EXE NAMES clang clang-14 # clang-15
    PATHS ${CURRENT_INSTALLED_DIR}/bin
    REQUIRED
)
message(STATUS "Found clang: ${CLANG_EXE}")
get_filename_component(CLANG_TOOL_DIR "${CLANG_EXE}" PATH)

find_path(LLVM_LIBRARY_DIR NAMES cmake/llvm/LLVMConfig.cmake
    PATHS ${CURRENT_INSTALLED_DIR}/lib
        #   /usr/lib/llvm-15/lib
    REQUIRED NO_DEFAULT_PATH
)
find_path(LLVM_DIR NAMES LLVMConfig.cmake
    PATHS ${LLVM_LIBRARY_DIR}/cmake/llvm
    REQUIRED
)
message(STATUS "Found LLVMConfig.cmake: ${LLVM_DIR}")

list(APPEND PLATFORM_OPTIONS
    -DClang_DIR:PATH=${Clang_DIR}
    -DSWIFT_NATIVE_CLANG_TOOLS_PATH:PATH=${CLANG_TOOL_DIR}
    -DSWIFT_BUILD_RUNTIME_WITH_HOST_COMPILER=ON
    -DSWIFT_PREBUILT_SWIFT=OFF
    -DSWIFT_RUN_TESTS_WITH_HOST_COMPILER=ON

    -DCLANG_BUILD_TOOLS=OFF # suppress custom targets from AddLLVM.cmake

    -DLLVM_DIR:PATH="${LLVM_DIR}"
    -DLLVM_MAIN_SRC_DIR:PATH="${LLVM_STAGING_SOURCE_PATH}/llvm"

    -DLLVM_ENABLE_LIBCXX=ON
    -DLLVM_ENABLE_IDE=ON
    -DLLVM_LIBRARY_DIR:PATH="${LLVM_LIBRARY_DIR}"
    # -DLLVM_BUILD_LIBRARY_DIR:PATH="${LLVM_LIBRARY_DIR}"
)

# todo: experimental features
vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        sourcekit SWIFT_BUILD_SOURCEKIT
        sourcekit SWIFT_ENABLE_SOURCEKIT_TESTS
        tools SWIFT_INCLUDE_TOOLS
        tools SWIFT_TOOLS_ENABLE_LTO
        tests SWIFT_INCLUDE_TESTS
        tests SWIFT_INCLUDE_TEST_BINARIES
        docs  SWIFT_INCLUDE_APINOTES
        docs  SWIFT_INCLUDE_DOCS
        exp   SWIFT_EXPERIMENTAL_EXTRA_FLAGS
        exp   SWIFT_EXPERIMENTAL_EXTRA_REGEXP_FLAGS
        exp   SWIFT_EXPERIMENTAL_EXTRA_NEGATIVE_REGEXP_FLAGS
)

if(VCPKG_TARGET_IS_OSX)
    set(GENERATOR Xcode)
else()
    set(GENERATOR Ninja)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    GENERATOR ${GENERATOR}
    OPTIONS
        ${FEATURE_OPTIONS} ${PLATFORM_OPTIONS}

        # -DSWIFT_SWIFT_PARSER=OFF
        -DSWIFT_BUILD_DYNAMIC_STDLIB=OFF
        -DSWIFT_BUILD_STATIC_STDLIB=OFF
        -DSWIFT_BUILD_STDLIB=OFF

        -DPython3_EXECUTABLE:FILEPATH="${PYTHON3}"
        -DBUILD_SHARED_LIBS=ON
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON
        -DSWIFT_COMPILER_VERSION:STRING="346fb02"
        -DSWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE:PATH=${SYNTAX_SOURCE_PATH}
        # -DSWIFT_BUILD_HOST_DISPATCH=OFF
        -DSWIFT_ENABLE_DISPATCH=ON
        -DSWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY=OFF
        -DSWIFT_CONCURRENCY_GLOBAL_EXECUTOR=dispatch
        -DLLVM_USE_SANITIZER=OFF
    OPTIONS_DEBUG
        -DSWIFT_RUNTIME_ENABLE_LEAK_CHECKER=OFF
    MAYBE_UNUSED_VARIABLES
        CLANG_BUILD_TOOLS
)
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
