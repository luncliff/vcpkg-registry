if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
    set(VCPKG_POLICY_SKIP_ARCHITECTURE_CHECK enabled)
    set(VCPKG_POLICY_SKIP_DUMPBIN_CHECKS disabled)
    # see https://github.com/apple/swift-corelibs-libdispatch/pull/569
    vcpkg_download_distfile(TSD_DTOR_PATCH
        URLS "https://patch-diff.githubusercontent.com/raw/apple/swift-corelibs-libdispatch/pull/569.diff"
        FILENAME libdispatch-pr-569.patch
        SHA512 61676555b23796e61923f6dc284f5713386de5704daa4ced0bc1824a18203d30c4e9c151278be5e19532f73e2ece2664ef92b5b3fca00c0390fefaddb9c4154d
    )
    # see https://github.com/apple/swift-corelibs-libdispatch/pull/598
    vcpkg_download_distfile(X86_BUILD_PATCH
        URLS "https://patch-diff.githubusercontent.com/raw/apple/swift-corelibs-libdispatch/pull/598.diff"
        FILENAME libdispatch-pr-598.patch
        SHA512 b0a8b3375b2c809173c6dd3df836f102efe004fac535338ec4864b05b8e184a737f1d624cfbb670ddbce480f3ed6d883cf3a7ac2c829cf0ee1b7beea623411ae
    )
    list(APPEND PLATFORM_PATCHES
        "${TSD_DTOR_PATCH}" "${X86_BUILD_PATCH}"
    )
elseif(VCPKG_TARGET_IS_ANDROID)
    # check https://github.com/apple/swift-corelibs-libdispatch/pull/568 for the details...
    vcpkg_download_distfile(NDK23_STDATOMIC_PATCH
        URLS "https://patch-diff.githubusercontent.com/raw/apple/swift-corelibs-libdispatch/pull/568.diff"
        FILENAME libdispatch-pr-568.patch
        SHA512 af23d9530a1c9d10193ab977be632b6393b6966db367c5ee8463ad79fcc2388bed233dcd77439f035b4c4609d99329a17c58fef53cce1a1000a70a41d7406df4
    )
    list(APPEND PLATFORM_PATCHES "${NDK23_STDATOMIC_PATCH}")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/swift-corelibs-libdispatch
    REF swift-5.5-RELEASE
    SHA512 58ad7122d2fac7b117f4e81eec2b5c1dfdf5256865337110d660790744e83c3fea5e82fbe521b6e56fd0e2f09684e5e1475cf2cac67989a8f78dd0a284fb0d21
    HEAD_REF master
    PATCHES
        ${PLATFORM_PATCHES}
        fix-cmake.patch
        fix-sources-windows.patch
)

if(VCPKG_TARGET_IS_WINDOWS)
    if(DEFINED VCPKG_CMAKE_SYSTEM_NAME) # ex) WindowsStore
        list(APPEND PLATFORM_OPTIONS -DCMAKE_SYSTEM_NAME=${VCPKG_CMAKE_SYSTEM_NAME})
    else()
        list(APPEND PLATFORM_OPTIONS -DCMAKE_SYSTEM_NAME=Windows)
    endif()

    # MSVC is unsupported compiler. We will use Clang
    vcpkg_find_acquire_program(CLANG)
    message(STATUS "Found clang: ${CLANG}")

    # Actually, we need clang-cl, not clang
    get_filename_component(CLANG_PATH "${CLANG}" PATH)
    find_program(CLANG_CL_EXE NAMES clang-cl HINTS ${LLVM_TOOL_PATH} ${CLANG_PATH} REQUIRED)
    message(STATUS "Found clang-cl: ${CLANG_CL_EXE}")

    # get_filename_component(CLANG_CL_PATH "${CLANG_CL_EXE}" PATH)
    # vcpkg_add_to_path(PREPEND ${CLANG_CL_PATH})
    # message(STATUS "Prepend PATH: ${CLANG_CL_PATH}")

    list(APPEND COMPILE_FLAGS "-fms-compatibility")
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        list(APPEND COMPILE_FLAGS -m64)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        list(APPEND COMPILE_FLAGS -m32)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        list(APPEND COMPILE_FLAGS -m64 --target=arm-none-win32)
    else()
        message(FATAL_ERROR "not supported")
    endif()

    # CMAKE_C_COMPILER_ID=Clang can be deduced by Ninja
    list(APPEND PLATFORM_OPTIONS
        -DCMAKE_C_COMPILER:PATH=${CLANG_CL_EXE}
        -DCMAKE_C_FLAGS="${COMPILE_FLAGS}"
        -DCMAKE_CXX_COMPILER:PATH=${CLANG_CL_EXE}
        -DCMAKE_CXX_FLAGS="${COMPILE_FLAGS}"
    )
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    GENERATOR Ninja
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
# if(VCPKG_TARGET_IS_WINDOWS AND VCPKG_CROSSCOMPILING)
#     # The build.ninja uses LIBPATH for current host architecture. We have to fix that.
#     get_filename_component(BUILD_FILE_DBG ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg/build.ninja ABSOLUTE)
#     vcpkg_replace_string(${BUILD_FILE_DBG} "${HOST_ARCH}" "${VCPKG_TARGET_ARCHITECTURE}")
#     get_filename_component(BUILD_FILE_REL ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/build.ninja ABSOLUTE)
#     vcpkg_replace_string(${BUILD_FILE_REL} "${HOST_ARCH}" "${VCPKG_TARGET_ARCHITECTURE}")
# endif()

vcpkg_cmake_install()
vcpkg_copy_pdbs()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share"
                    "${CURRENT_PACKAGES_DIR}/debug/include"
)
file(INSTALL "${SOURCE_PATH}/LICENSE"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright
)
