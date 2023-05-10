
# see https://developer.apple.com/library/archive/documentation/DeveloperTools/Reference/XcodeBuildSettingRef/1-Build_Setting_Reference/build_setting_ref.html
if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    # By default, the project generates dynamic framework.
    # These patches have NO effect. But may help debugging in the SOURCE_PATH ...
    list(APPEND SWIFTPM_PATCHES swiftpm-product-dynamic.patch)
    # list(APPEND XCODEBUILD_PARAMS "MACH_O_TYPE=mh_dylib")
elseif(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    list(APPEND SWIFTPM_PATCHES swiftpm-product-static.patch)
    list(APPEND XCODEBUILD_PARAMS "MACH_O_TYPE=staticlib")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/swift-nio-ssl
    REF 2.24.0
    SHA512 2cbb7a2294f518a5c3159dcdfd66227eb08b3aa83092f99d201a1a3ea943272b78249dab5b0150fa91f6373cbdb1771a0e9e42144b311ea0845a47996a6f43be
    HEAD_REF main
    PATCHES
        ${SWIFTPM_PATCHES}
)

vcpkg_from_github(
    OUT_SOURCE_PATH NIO_SOURCE_PATH
    REPO apple/swift-nio
    REF 2.42.0
    SHA512 cea980fc5b0ea74314932c8986799233731c3bfba850fef4b1a11d613b7b58c0b3ddb0dc28a7a1b04ccc9a24bafb8709e7a6335792fb4e0acaad182c2158e4cc
    HEAD_REF main
)

# see vcpkg_extract_source_archive
if(NOT _VCPKG_EDITABLE)
    file(REMOVE_RECURSE "${SOURCE_PATH}/.build" "${SOURCE_PATH}/build")
endif()

# use symbolic link to prevent SwiftPM checkouts
get_filename_component(CUSTOM_BUILDTREES_DIR "${SOURCE_PATH}" PATH)
file(CREATE_LINK "${NIO_SOURCE_PATH}" "${CUSTOM_BUILDTREES_DIR}/swift-nio" SYMBOLIC)

function(xcodebuild_build_swiftpm)
    cmake_parse_arguments(PARSE_ARGV 0 xc "COPY_AFTER_BUILD" "SCHEME;DESTINATION;OUTPUT_DIR;LOGNAME" "PARAMS")
    if(DEFINED xc_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} can't handle extra arguments: ${xc_UNPARSED_ARGUMENTS}")
    endif()

    # required arguments
    if(NOT DEFINED xc_SCHEME)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} requires: SCHEME")
    endif()
    if(NOT DEFINED xc_DESTINATION)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} requires: DESTINATION")
    endif()

    # optional arguments with default values
    if(NOT DEFINED xc_LOGNAME)
        set(xc_LOGNAME "build")
    endif()
    if(NOT DEFINED xc_WORKING_DIRECTORY)
        set(xc_WORKING_DIRECTORY "${SOURCE_PATH}")
    endif()
    if(NOT DEFINED xc_OUTPUT_DIR)
        get_filename_component(xc_OUTPUT_DIR "${xc_WORKING_DIRECTORY}/build" ABSOLUTE)
    endif()

    # expected build output location of Package.swift generated xcodeproj
    if(VCPKG_TARGET_IS_OSX)
        get_filename_component(OUTPUT_DIR_DBG ${xc_OUTPUT_DIR}/Debug    ABSOLUTE)
        get_filename_component(OUTPUT_DIR_REL ${xc_OUTPUT_DIR}/Release  ABSOLUTE)
    elseif(VCPKG_TARGET_IS_IOS)
        get_filename_component(OUTPUT_DIR_DBG ${xc_OUTPUT_DIR}/Debug-iphoneos   ABSOLUTE)
        get_filename_component(OUTPUT_DIR_REL ${xc_OUTPUT_DIR}/Release-iphoneos ABSOLUTE)
        if(VCPKG_TARGET_IS_SIMULATOR)
            get_filename_component(OUTPUT_DIR_DBG ${xc_OUTPUT_DIR}/Debug-iphonesimulator    ABSOLUTE)
            get_filename_component(OUTPUT_DIR_REL ${xc_OUTPUT_DIR}/Release-iphonesimulator  ABSOLUTE)
        endif()
    else()
        message(FATAL_ERROR "Unsupported target platform")
    endif()

    # Let's start build with xcodebuild ...
    find_program(XCODEBUILD NAMES xcodebuild REQUIRED)

    message(STATUS "Building ${TARGET_TRIPLET}-dbg")
    vcpkg_execute_required_process(
        COMMAND ${XCODEBUILD} -scheme ${xc_SCHEME} -destination ${xc_DESTINATION} -jobs ${VCPKG_CONCURRENCY} -configuration Debug ${xc_PARAMS}
        WORKING_DIRECTORY ${xc_WORKING_DIRECTORY}
        LOGNAME "${xc_LOGNAME}-${TARGET_TRIPLET}-dbg"
    )
    if(xc_COPY_AFTER_BUILD)
        file(COPY "${OUTPUT_DIR_DBG}/${FRAMEWORK_FILENAME}" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
    endif()

    message(STATUS "Building ${TARGET_TRIPLET}-rel")
    vcpkg_execute_required_process(
        COMMAND ${XCODEBUILD} -scheme ${xc_SCHEME} -destination ${xc_DESTINATION} -jobs ${VCPKG_CONCURRENCY} -configuration Release ${xc_PARAMS}
        WORKING_DIRECTORY ${xc_WORKING_DIRECTORY}
        LOGNAME "${xc_LOGNAME}-${TARGET_TRIPLET}-rel"
    )
    if(xc_COPY_AFTER_BUILD)
        file(COPY "${OUTPUT_DIR_REL}/${FRAMEWORK_FILENAME}" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    endif()
endfunction()

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(ARCH "arm64")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(ARCH "x86_64")
else()
    message(FATAL_ERROR "Unsupported architecture: ${VCPKG_TARGET_ARCHITECTURE}")
endif()

if(VCPKG_TARGET_IS_OSX)
    set(SDK macosx)
    set(PLATFORM macOS)
    list(APPEND XCODEBUILD_DESTINATION "platform=${PLATFORM},arch=${ARCH}")
elseif(VCPKG_TARGET_IS_IOS)
    set(SDK iphoneos)
    set(PLATFORM iOS)
    if(VCPKG_TARGET_IS_SIMULATOR)
        set(SDK iphonesimulator)
        set(PLATFORM "iOS Simulator")
    endif()
    list(APPEND XCODEBUILD_DESTINATION "generic/platform=${PLATFORM}")
else()
    message(FATAL_ERROR "Unsupported target platform")
endif()

find_program(SWIFT NAMES swift REQUIRED)
message(STATUS "Using swift: ${SWIFT}")

find_program(XCODEBUILD NAMES xcodebuild REQUIRED)
message(STATUS "Using xcodebuild: ${XCODEBUILD}")
if(DEFINED XCODEBUILD_DESTINATION)
message(STATUS "  -destination ${XCODEBUILD_DESTINATION}")
endif()
if(DEFINED XCODEBUILD_PARAMS)
message(STATUS "  ${XCODEBUILD_PARAMS}")
endif()

set(ENV{SWIFTCI_USE_LOCAL_DEPS} true)

# before build, record some project info for CI environment debugging
vcpkg_execute_required_process(
    COMMAND ${XCODEBUILD} -list
    LOGNAME "project-schemes"
    WORKING_DIRECTORY ${SOURCE_PATH}
)
vcpkg_execute_required_process(
    COMMAND ${XCODEBUILD} -scheme CNIOBoringSSL -showdestinations
    LOGNAME "project-destinations"
    WORKING_DIRECTORY ${SOURCE_PATH}
)

# build some targets
xcodebuild_build_swiftpm(SCHEME CNIOBoringSSL
    DESTINATION ${XCODEBUILD_DESTINATION}
    PARAMS ${XCODEBUILD_PARAMS}
    LOGNAME "build1" COPY_AFTER_BUILD
)

# install public/private headers
file(GLOB headers
    "${SOURCE_PATH}/Sources/CNIOBoringSSL/include/*.h"
)
file(INSTALL ${headers} DESTINATION "${CURRENT_PACKAGES_DIR}/include/CNIOBoringSSL")

file(GLOB ssl_headers
    "${SOURCE_PATH}/Sources/CNIOBoringSSL/ssl/*.h"
    # ...
)
file(INSTALL ${ssl_headers} DESTINATION "${CURRENT_PACKAGES_DIR}/include/ssl")

file(GLOB crypto_headers
    "${SOURCE_PATH}/Sources/CNIOBoringSSL/crypto/internal.h"
    # ...
)
file(INSTALL ${crypto_headers} DESTINATION "${CURRENT_PACKAGES_DIR}/include/crypto")

file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
