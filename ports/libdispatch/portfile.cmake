if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
    set(VCPKG_POLICY_SKIP_ARCHITECTURE_CHECK enabled)
    set(VCPKG_POLICY_SKIP_DUMPBIN_CHECKS disabled)
    if(VCPKG_CROSSCOMPILING)
        message(WARNING "Cross compiling is not tested for Windows")
    endif()

    list(APPEND PLATFORM_PATCHES fix-windows.patch)
    if(TARGET_TRIPLET MATCHES "x86-windows")
        list(APPEND PLATFORM_PATCHES fix-x86-windows.patch)
    elseif(TARGET_TRIPLET MATCHES "arm64-windows")
        # ... not tested ...
    endif()
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/swift-corelibs-libdispatch
    REF swift-5.5-RELEASE
    SHA512 58ad7122d2fac7b117f4e81eec2b5c1dfdf5256865337110d660790744e83c3fea5e82fbe521b6e56fd0e2f09684e5e1475cf2cac67989a8f78dd0a284fb0d21
    HEAD_REF master
    PATCHES
        fix-out-of-tree.patch
        fix-warnings.patch
        ${PLATFORM_PATCHES}
)

if(VCPKG_TARGET_IS_WINDOWS)
    # MSVC is unsupported compiler. We will use Clang
    vcpkg_find_acquire_program(CLANG)
    message(STATUS "Found clang: ${CLANG}")

    # We need to use clang toolchain executables in Visual Studio Tools
    get_filename_component(CLANG_PATH "${CLANG}" PATH)
    if(VCPKG_TARGET_ARCHITECTURE MATCHES "x86")
        # Acquire PATH of LLVM tools for x86 target
        # case: Visual Studio 2019
        if(CLANG_PATH MATCHES "VC/Tools/Llvm/x64") 
            get_filename_component(LLVM_TOOL_PATH "${CLANG_PATH}" PATH)
            get_filename_component(LLVM_TOOL_PATH "${LLVM_TOOL_PATH}" PATH)
            get_filename_component(LLVM_TOOL_PATH "${LLVM_TOOL_PATH}/bin" ABSOLUTE)
        else()
            message(FATAL_ERROR "Unexpected install location: ${CLANG_PATH}")
        endif()
        # list(APPEND PLATFORM_OPTIONS
        #     -DCMAKE_EXE_LINKER_FLAGS="/machine:x86"
        # )
    endif()

    # Actually, we need clang-cl, not clang
    find_program(CLANG_CL_EXE NAMES clang-cl HINTS ${LLVM_TOOL_PATH} ${CLANG_PATH} REQUIRED)
    message(STATUS "Found clang-cl(${VCPKG_TARGET_ARCHITECTURE}): ${CLANG_CL_EXE}")

    get_filename_component(CLANG_CL_PATH "${CLANG_CL_EXE}" PATH)
    vcpkg_add_to_path(PREPEND ${CLANG_CL_PATH})
    message(STATUS "Prepend PATH: ${CLANG_CL_PATH}")

    # CMAKE_C_COMPILER_ID=Clang can be deduced by Ninja
    list(APPEND PLATFORM_OPTIONS
        -DCMAKE_C_COMPILER:PATH=${CLANG_CL_EXE}
        -DCMAKE_C_FLAGS="-fms-compatibility"
        -DCMAKE_CXX_COMPILER:PATH=${CLANG_CL_EXE}
        -DCMAKE_CXX_FLAGS="-fms-compatibility"
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
vcpkg_cmake_install()
vcpkg_copy_pdbs()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share"
                    "${CURRENT_PACKAGES_DIR}/debug/include"
)
file(INSTALL "${SOURCE_PATH}/LICENSE"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright
)
