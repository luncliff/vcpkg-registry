if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
    set(VCPKG_POLICY_SKIP_ARCHITECTURE_CHECK disabled)
    set(VCPKG_POLICY_SKIP_DUMPBIN_CHECKS disabled)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/swift-corelibs-libdispatch
    REF swift-5.10.1-RELEASE
    SHA512 fa8278adbdfd5b041c89a7b14a17aaa805a6f4db12221ff469288bb8d945fd28f16a8d66f56148aeba2e6be30bd6655fbe375d7843d1cb54407527d998e6d6fa
    PATCHES
        fix-cmake.patch
        fix-sources-windows.patch
)

if(VCPKG_TARGET_IS_WINDOWS)
    # MSVC is unsupported compiler. We will use Clang
    vcpkg_find_acquire_program(CLANG)
    message(STATUS "Using clang: ${CLANG}")

    # Actually, we need clang-cl, not clang
    get_filename_component(CLANG_PATH "${CLANG}" PATH)
    find_program(CLANG_CL_EXE NAMES clang-cl HINTS ${LLVM_TOOL_PATH} ${CLANG_PATH} REQUIRED)
    message(STATUS "Using clang-cl: ${CLANG_CL_EXE}")

    # Visual Studio with ClangCL
    set(VCPKG_PLATFORM_TOOLSET ClangCL) # CMAKE_GENERATOR_TOOLSET
    set(GENERATOR_OPTIONS WINDOWS_USE_MSBUILD)

    if(VCPKG_TARGET_IS_UWP) # error MSB8020
        list(APPEND COMPILE_FLAGS "-fms-compatibility")
        list(APPEND PLATFORM_OPTIONS
            -DCMAKE_C_COMPILER:PATH=${CLANG_CL_EXE}
            -DCMAKE_CXX_COMPILER:PATH=${CLANG_CL_EXE}
        )
    endif()
    # todo: fix linker errors in arm64-windows
    # todo: support x64-uwp, arm64-uwp
else()
    list(APPEND GENERATOR_OPTIONS GENERATOR Ninja)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    ${GENERATOR_OPTIONS}
    OPTIONS
        ${PLATFORM_OPTIONS}
        -DHAVE_OBJC=OFF
        -DENABLE_SWIFT=OFF
        -DENABLE_THREAD_LOCAL_STORAGE=ON
        -DENABLE_DTRACE=OFF
        -DBUILD_TESTING=OFF
        -DINSTALL_PRIVATE_HEADERS=ON
    OPTIONS_DEBUG
        -DDISPATCH_ENABLE_ASSERTS=ON
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share"
                    "${CURRENT_PACKAGES_DIR}/debug/include"
)
# file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
