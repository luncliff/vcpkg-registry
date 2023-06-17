vcpkg_minimum_required(VERSION 2023-01-24) # https://github.com/microsoft/vcpkg-tool/releases
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

# todo: Xml2, FFI, ZLIB, etc...
set(VCPKG_PREFER_SYSTEM_LIBS ON)

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
    # PATCHES
    #     fix-linux-cmake.patch
)

if(VCPKG_TARGET_IS_LINUX)
    message(STATUS "Required APT packages")
    message(STATUS "  clang-15 clang-tools-15 llvm-15-dev libclang-15-dev")

    find_path(Clang_DIR NAMES ClangConfig.cmake
        PATHS /usr/lib/llvm-15/lib/cmake/clang
              /usr/lib/cmake/clang-15
        REQUIRED
    )
    message(STATUS "Found ClangConfig.cmake: ${Clang_DIR}")

    find_path(LLVM_LIBRARY_DIR NAMES cmake/llvm/LLVMConfig.cmake PATHS /usr/lib/llvm-15/lib REQUIRED)
    find_path(LLVM_DIR NAMES LLVMConfig.cmake
        PATHS ${LLVM_LIBRARY_DIR}/cmake/llvm
        REQUIRED
    )
    message(STATUS "Found LLVMConfig.cmake: ${LLVM_DIR}")

    list(APPEND PLATFORM_OPTIONS
        -DClang_DIR:PATH="${Clang_DIR}"
        -DCLANG_BUILD_TOOLS=OFF # suppress custom targets from AddLLVM.cmake
        -DLLVM_DIR:PATH="${LLVM_DIR}"
        -DLLVM_MAIN_SRC_DIR:PATH="${LLVM_LIBRARY_DIR}"
        -DLLVM_ENABLE_LIBCXX=ON
        -DLLVM_ENABLE_IDE=ON
        -DLLVM_LIBRARY_DIR:PATH="${LLVM_LIBRARY_DIR}"
        # -DLLVM_BUILD_LIBRARY_DIR:PATH="${LLVM_LIBRARY_DIR}"
    )
endif()

# todo: experimental features
vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        sourcekit SWIFT_BUILD_SOURCEKIT
        tools SWIFT_INCLUDE_TOOLS
        tools SWIFT_TOOLS_ENABLE_LTO
        tests SWIFT_INCLUDE_TESTS
        tests SWIFT_INCLUDE_TEST_BINARIES
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
        ${PLATFORM_OPTIONS}
        -DBUILD_SHARED_LIBS=ON
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON
        -DSWIFT_COMPILER_VERSION:STRING="346fb02"
        -DSWIFT_INCLUDE_APINOTES=ON
        -DSWIFT_INCLUDE_DOCS=OFF
        # -DSWIFT_BUILD_RUNTIME_WITH_HOST_COMPILER=ON
        -DSWIFT_RUN_TESTS_WITH_HOST_COMPILER=ON
        -DSWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE:PATH=${SYNTAX_SOURCE_PATH}
        -DSWIFT_ENABLE_DISPATCH=ON
        -DSWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY=OFF
    MAYBE_UNUSED_VARIABLES
        CLANG_BUILD_TOOLS
)
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
