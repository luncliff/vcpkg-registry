vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY) 

# See https://openjdk.org/groups/build/doc/building.html or doc/building.md
# Prepare toolchains like BASH, MAKE, and BOOTJDK_PATH...
if(VCPKG_TARGET_IS_WINDOWS)
    include(${CMAKE_CURRENT_LIST_DIR}/windows-setup.cmake)
endif()
if(NOT DEFINED BOOTJDK_PATH)
    message(FATAL_ERROR "BOOTJDK_PATH is required")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO openjdk/jdk
    REF jdk-23+10
    SHA512 cccb0150c3662426a668b11f3d4b0652df53a421c39a42d88fc177f25f04df0ced6cb7ba5e47a44edb79d13d1677ca5877e066b2f98a7edac49ed7975fa61736
    HEAD_REF master
)

# for command debugging of `configure`
vcpkg_execute_required_process(
    COMMAND ${BASH} configure --help
    LOGNAME configure-help-${TARGET_TRIPLET}
    WORKING_DIRECTORY "${SOURCE_PATH}"
)

set(BUILD_DIR_DBG "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg")
set(BUILD_DIR_REL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")

file(REMOVE_RECURSE "${BUILD_DIR_DBG}" "${BUILD_DIR_REL}")
get_filename_component(SOURCE_DIR_NAME "${SOURCE_PATH}" NAME)
file(COPY "${SOURCE_PATH}" DESTINATION "${CURRENT_BUILDTREES_DIR}")
file(RENAME "${CURRENT_BUILDTREES_DIR}/${SOURCE_DIR_NAME}" "${BUILD_DIR_DBG}")
file(COPY "${SOURCE_PATH}" DESTINATION "${CURRENT_BUILDTREES_DIR}")
file(RENAME "${CURRENT_BUILDTREES_DIR}/${SOURCE_DIR_NAME}" "${BUILD_DIR_REL}")

# todo: replace zip, freetype, etc

message(STATUS "Configuring ${TARGET_TRIPLET}-dbg")
vcpkg_execute_required_process(
    COMMAND ${BASH} configure
        "--prefix=${CURRENT_PACKAGES_DIR}/debug"
        "--exec-prefix=${CURRENT_PACKAGES_DIR}/debug"
        "--enable-debug" # replaces "--with-debug-level=fastdebug"
        "--with-version-string=23+10"
        "--with-boot-jdk=${BOOTJDK_PATH}"
        "--with-jvm-variants=server" # client, minimal, etc
        "--with-target-bits=64"
        "--with-source-date=version"
        "--with-build-user=vcpkg"
        ${CONFIG_TOOLCHAIN_OPTIONS}
    LOGNAME config-${TARGET_TRIPLET}-dbg
    WORKING_DIRECTORY "${BUILD_DIR_DBG}"
)

# for command debugging of `make`
vcpkg_execute_required_process(
    COMMAND ${MAKE} help
    LOGNAME make-help-${BUILD_DIR_DBG}-dbg
    WORKING_DIRECTORY "${BUILD_DIR_DBG}"
)

message(STATUS "Building ${TARGET_TRIPLET}-dbg")
vcpkg_execute_required_process(
    COMMAND ${MAKE} JOBS=${VCPKG_CONCURRENCY} LOG=info
        images docs # all
    LOGNAME build-${TARGET_TRIPLET}-dbg
    WORKING_DIRECTORY "${BUILD_DIR_DBG}"
)

message(STATUS "Configuring ${TARGET_TRIPLET}-rel")
vcpkg_execute_required_process(
    COMMAND ${BASH} configure
        "--prefix=${CURRENT_PACKAGES_DIR}"
        "--exec-prefix=${CURRENT_PACKAGES_DIR}"
        "--with-version-string=23+10"
        "--with-boot-jdk=${BOOTJDK_PATH}"
        "--with-jvm-variants=server" # client, minimal, etc
        "--with-target-bits=64"
        "--with-source-date=version"
        "--with-build-user=vcpkg"
        ${CONFIG_TOOLCHAIN_OPTIONS}
    LOGNAME config-${TARGET_TRIPLET}-rel
    WORKING_DIRECTORY "${BUILD_DIR_REL}"
)

message(STATUS "Building ${TARGET_TRIPLET}-rel")
vcpkg_execute_required_process(
    COMMAND ${MAKE} JOBS=${VCPKG_CONCURRENCY} LOG=info
        images docs
    LOGNAME build-${TARGET_TRIPLET}-rel
    WORKING_DIRECTORY "${BUILD_DIR_REL}"
)

if(VCPKG_TARGET_IS_WINDOWS)
    set(OUTPUT_NAME "windows-x86_64-server-release")
    get_filename_component(OUTPUT_DIR "${BUILD_DIR_REL}/build/${OUTPUT_NAME}/jdk" ABSOLUTE)
    file(COPY "${OUTPUT_DIR}/" DESTINATION "${CURRENT_PACKAGES_DIR}")
    include(${CMAKE_CURRENT_LIST_DIR}/windows-cleanup.cmake)
elseif(VCPKG_TARGET_IS_LINUX)
    include(${CMAKE_CURRENT_LIST_DIR}/linux-cleanup.cmake)
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/modules"
    # ...
)

file(INSTALL "${SOURCE_PATH}/README.md"
             "${SOURCE_PATH}/ADDITIONAL_LICENSE_INFO" 
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
