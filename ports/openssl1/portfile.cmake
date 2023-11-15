if(EXISTS ${CURRENT_INSTALLED_DIR}/include/openssl/ssl.h)
    message(FATAL_ERROR "Can't build '${PORT}' if another SSL library is installed. Please remove existing one and try install '${PORT}' again if you need it.")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO openssl/openssl
    REF OpenSSL_1_1_1w
    SHA512 adfbcd5a1f3b80c15da608b7234a7bdc50afb1b98f8dc07b712c157058a01f21e1832fdbe1024a3ec7f5e335de3da003e5dccab044ec7510ad60b2b357529a3f
)

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    list(APPEND CONFIGURE_OPTIONS shared)
else()
    list(APPEND CONFIGURE_OPTIONS no-shared)
endif()

# see ${SOURCE_PATH}/INSTALL.md
list(APPEND CONFIGURE_OPTIONS
    no-zlib
    no-ui-console   # Don't build with the User Interface (UI) console method
    no-makedepend   # Don't generate dependencies
    no-tests        # Don't build test programs or run any tests
)
if(VCPKG_TARGET_IS_UWP)
    list(APPEND CONFIGURE_OPTIONS no-async)
endif()
if(VCPKG_TARGET_IS_WINDOWS)
    # jom will build in parallel mode, we need /FS for PDB access
    list(APPEND CONFIGURE_OPTIONS -utf-8 -FS)

elseif(VCPKG_TARGET_IS_IOS)
    # see https://github.com/microsoft/vcpkg PR 12527
    # disable that makes linkage error (e.g. require stderr usage)
    list(APPEND CONFIGURE_OPTIONS no-stdio no-ui no-asm)

endif()

# Option: platform/architecture
include(${CMAKE_CURRENT_LIST_DIR}/detect_platform.cmake)

# Clean & copy source files for working directories
file(REMOVE_RECURSE "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
                    "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
)
get_filename_component(SOURCE_DIR_NAME "${SOURCE_PATH}" NAME)
file(COPY        "${SOURCE_PATH}"
     DESTINATION "${CURRENT_BUILDTREES_DIR}")
file(RENAME      "${CURRENT_BUILDTREES_DIR}/${SOURCE_DIR_NAME}"
                 "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg")
file(COPY        "${SOURCE_PATH}"
     DESTINATION "${CURRENT_BUILDTREES_DIR}")
file(RENAME      "${CURRENT_BUILDTREES_DIR}/${SOURCE_DIR_NAME}"
                 "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")

# see ${SOURCE_PATH}/NOTES-PERL.md
vcpkg_find_acquire_program(PERL)
get_filename_component(PERL_EXE_PATH "${PERL}" DIRECTORY)
vcpkg_add_to_path("${PERL_EXE_PATH}")

if(NOT VCPKG_HOST_IS_WINDOWS)
    # see ${SOURCE_PATH}/NOTES-UNIX.md
    find_program(MAKE make REQUIRED)
    get_filename_component(MAKE_EXE_PATH "${MAKE}" DIRECTORY)
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    # see ${SOURCE_PATH}/NOTES-WINDOWS.md
    vcpkg_find_acquire_program(NASM)
    get_filename_component(NASM_EXE_PATH "${NASM}" DIRECTORY)
    vcpkg_add_to_path(PREPEND "${NASM_EXE_PATH}")
    # note: jom is not for `vcpkg_add_to_path`
    vcpkg_find_acquire_program(JOM)

elseif(VCPKG_TARGET_IS_ANDROID)
    # see ${SOURCE_PATH}/NOTES-ANDROID.md
    if(NOT DEFINED ENV{ANDROID_NDK_ROOT} AND DEFINED ENV{ANDROID_NDK_HOME})
        message(STATUS "ENV{ANDROID_NDK_ROOT} will be set to $ENV{ANDROID_NDK_HOME}")
        set(ENV{ANDROID_NDK_ROOT} "$ENV{ANDROID_NDK_HOME}")
    endif()
    if(NOT DEFINED ENV{ANDROID_NDK_ROOT})
        message(FATAL_ERROR "ENV{ANDROID_NDK_ROOT} is required by ${SOURCE_PATH}/Configurations/15-android.conf")
    endif()
    if(VCPKG_HOST_IS_LINUX)
        set(NDK_HOST_TAG "linux-x86_64")
    elseif(VCPKG_HOST_IS_OSX)
        set(NDK_HOST_TAG "darwin-x86_64")
    elseif(VCPKG_HOST_IS_WINDOWS)
        set(NDK_HOST_TAG "windows-x86_64")
    else()
        message(FATAL_ERROR "Unknown NDK host platform")
    endif()
    get_filename_component(NDK_TOOL_PATH "$ENV{ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${NDK_HOST_TAG}/bin" ABSOLUTE)
    vcpkg_add_to_path(PREPEND "${NDK_TOOL_PATH}")

endif()

# Configure / Install
# note: we need a PERL so can't use `vcpkg_configure_make` directly...
message(STATUS "Configuring ${TARGET_TRIPLET}-dbg")
vcpkg_execute_required_process(
    COMMAND ${PERL} Configure ${OPENSSL_SHARED} ${CONFIGURE_OPTIONS} --debug
        ${PLATFORM}
        "--prefix=${CURRENT_PACKAGES_DIR}/debug"
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
    LOGNAME "configure-perl-${TARGET_TRIPLET}-dbg"
)
message(STATUS "Configuring ${TARGET_TRIPLET}-rel")
vcpkg_execute_required_process(
    COMMAND ${PERL} Configure ${OPENSSL_SHARED} ${CONFIGURE_OPTIONS}
        ${PLATFORM}
        "--prefix=${CURRENT_PACKAGES_DIR}"
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
    LOGNAME "configure-perl-${TARGET_TRIPLET}-rel"
)

if(VCPKG_TARGET_IS_UWP OR VCPKG_TARGET_IS_WINDOWS)
    message(STATUS "Building ${TARGET_TRIPLET}-dbg")
    vcpkg_execute_required_process(
        COMMAND ${JOM} /K /J ${VCPKG_CONCURRENCY} /F makefile install_dev
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
        LOGNAME "install-${TARGET_TRIPLET}-dbg"
    )
    message(STATUS "Building ${TARGET_TRIPLET}-rel")
    vcpkg_execute_required_process(
        COMMAND ${JOM} /K /J ${VCPKG_CONCURRENCY} /F makefile install_dev
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
        LOGNAME "install-${TARGET_TRIPLET}-rel"
    )
    vcpkg_copy_pdbs()

else()
    message(STATUS "Building ${TARGET_TRIPLET}-dbg")
    vcpkg_execute_required_process(
        COMMAND ${MAKE} -j ${VCPKG_CONCURRENCY} install_dev
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
        LOGNAME "install-${TARGET_TRIPLET}-dbg"
    )
    message(STATUS "Building ${TARGET_TRIPLET}-rel")
    vcpkg_execute_required_process(
        COMMAND ${MAKE} -j ${VCPKG_CONCURRENCY} install_dev
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
        LOGNAME "install-${TARGET_TRIPLET}-rel"
    )
    if(VCPKG_TARGET_IS_ANDROID AND VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
        # install_dev copies symbolic link. overwrite them with the actual shared objects
        file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg/libcrypto.so"
                     "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg/libssl.so"
             DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib"
        )
        file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/libcrypto.so"
                     "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/libssl.so"
             DESTINATION "${CURRENT_PACKAGES_DIR}/lib"
        )
    endif()
    # rename lib64 to lib for lib/pkgconfig
    if(EXISTS "${CURRENT_PACKAGES_DIR}/debug/lib64")
        file(RENAME "${CURRENT_PACKAGES_DIR}/debug/lib64" "${CURRENT_PACKAGES_DIR}/debug/lib")
    endif()
    if(EXISTS "${CURRENT_PACKAGES_DIR}/lib64")
        file(RENAME "${CURRENT_PACKAGES_DIR}/lib64" "${CURRENT_PACKAGES_DIR}/lib")
    endif()
    vcpkg_fixup_pkgconfig()

endif()

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    file(REMOVE "${CURRENT_PACKAGES_DIR}/debug/lib/libcrypto.a"
                "${CURRENT_PACKAGES_DIR}/debug/lib/libssl.a"
                "${CURRENT_PACKAGES_DIR}/lib/libcrypto.a"
                "${CURRENT_PACKAGES_DIR}/lib/libssl.a"
    )
    # see https://github.com/microsoft/vcpkg/issues/30805
    if(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
        find_program(INSTALL_NAME_TOOL install_name_tool
            HINTS /usr/bin /Library/Developer/CommandLineTools/usr/bin/
            REQUIRED
        )
        message(STATUS "Using install_name_tool: ${INSTALL_NAME_TOOL}")
        # ${CURRENT_PACKAGES_DIR}/debug/lib -> @rpath
        vcpkg_execute_build_process(
            COMMAND "${INSTALL_NAME_TOOL}" -id "@rpath/libcrypto.3.dylib" "libcrypto.3.dylib"
            WORKING_DIRECTORY "${CURRENT_PACKAGES_DIR}/debug/lib"
            LOGNAME "fix-rpath-dbg"
        )
        vcpkg_execute_build_process(
            COMMAND "${INSTALL_NAME_TOOL}" -change "${CURRENT_PACKAGES_DIR}/debug/lib/libcrypto.3.dylib" "@rpath/libcrypto.3.dylib" "libssl.3.dylib"
            WORKING_DIRECTORY "${CURRENT_PACKAGES_DIR}/debug/lib"
            LOGNAME "fix-rpath-dbg"
        )
        vcpkg_execute_build_process(
            COMMAND "${INSTALL_NAME_TOOL}" -id "@rpath/libssl.3.dylib" "libssl.3.dylib"
            WORKING_DIRECTORY "${CURRENT_PACKAGES_DIR}/debug/lib"
            LOGNAME "fix-rpath-dbg"
        )
        # ${CURRENT_PACKAGES_DIR}/lib -> @rpath
        vcpkg_execute_build_process(
            COMMAND "${INSTALL_NAME_TOOL}" -id "@rpath/libcrypto.3.dylib" "libcrypto.3.dylib"
            WORKING_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib"
            LOGNAME "fix-rpath-rel"
        )
        vcpkg_execute_build_process(
            COMMAND "${INSTALL_NAME_TOOL}" -change "${CURRENT_PACKAGES_DIR}/lib/libcrypto.3.dylib" "@rpath/libcrypto.3.dylib" "libssl.3.dylib"
            WORKING_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib"
            LOGNAME "fix-rpath-rel"
        )
        vcpkg_execute_build_process(
            COMMAND "${INSTALL_NAME_TOOL}" -id "@rpath/libssl.3.dylib" "libssl.3.dylib"
            WORKING_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib"
            LOGNAME "fix-rpath-rel"
        )
    endif()
else()
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/bin"
                        "${CURRENT_PACKAGES_DIR}/bin"
    )
    if(VCPKG_TARGET_IS_WINDOWS)
        file(REMOVE "${CURRENT_PACKAGES_DIR}/debug/lib/ossl_static.pdb"
                    "${CURRENT_PACKAGES_DIR}/lib/ossl_static.pdb"
        )
    endif()
endif()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
