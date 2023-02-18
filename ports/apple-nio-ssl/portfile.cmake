
# MACH_O_TYPE = staticlib;
if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    list(APPEND SWIFTPM_PATCHES swiftpm-product-dynamic.patch)
elseif(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    list(APPEND SWIFTPM_PATCHES swiftpm-product-static.patch)
    list(APPEND XCODEBUILD_PARAMS "MACH_O_TYPE=staticlib")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/swift-nio-ssl
    REF 2.23.0
    SHA512 a7d4478f3ebd8dd1ee78c71afef610c33b74fb1b38054ef352dccbc454b8c56b30158c63d20d8468fa17e3f688445814ea743b841bbac28b8639bc81cef86632
    HEAD_REF main
    PATCHES
        swiftpm-use-local.patch
        ${SWIFTPM_PATCHES}
)

vcpkg_from_github(
    OUT_SOURCE_PATH NIO_SOURCE_PATH
    REPO apple/swift-nio
    REF 2.42.0
    SHA512 cea980fc5b0ea74314932c8986799233731c3bfba850fef4b1a11d613b7b58c0b3ddb0dc28a7a1b04ccc9a24bafb8709e7a6335792fb4e0acaad182c2158e4cc
    HEAD_REF main
)

# use source folder so `--editable` can take effect always
# see vcpkg_extract_source_archive
if(NOT _VCPKG_EDITABLE)
    file(REMOVE_RECURSE "${SOURCE_PATH}/.build" "${SOURCE_PATH}/build")
endif()

# use symbolic link to prevent SwiftPM checkouts
get_filename_component(CUSTOM_BUILDTREES_DIR "${SOURCE_PATH}" PATH)
file(CREATE_LINK "${NIO_SOURCE_PATH}" "${CUSTOM_BUILDTREES_DIR}/swift-nio" SYMBOLIC)

# todo: add some comments
function(swiftpm_generatate_xcodeproj)
    cmake_parse_arguments(PARSE_ARGV 0 swiftpm "" "LOGNAME" "PARAMS")
    if(DEFINED xc_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} can't handle extra arguments: ${xc_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT DEFINED swiftpm_LOGNAME)
        set(swiftpm_LOGNAME "generate")
    endif()
    if(NOT DEFINED swiftpm_WORKING_DIRECTORY)
        set(swiftpm_WORKING_DIRECTORY "${SOURCE_PATH}")
    endif()

    find_program(SWIFT NAMES swift REQUIRED)
    message(STATUS "Generating Xcode project from Package.swift")
    vcpkg_execute_required_process(
        COMMAND ${SWIFT} package generate-xcodeproj ${swiftpm_PARAMS}
        WORKING_DIRECTORY ${swiftpm_WORKING_DIRECTORY}
        LOGNAME "${swiftpm_LOGNAME}-${TARGET_TRIPLET}"
    )
endfunction()

# todo: add some comments
function(xcodebuild_build_framework)
    cmake_parse_arguments(PARSE_ARGV 0 xc "COPY_AFTER_BUILD" "PROJECT;FRAMEWORK;OUTPUT_DIR;LOGNAME" "PARAMS")
    if(DEFINED xc_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} can't handle extra arguments: ${xc_UNPARSED_ARGUMENTS}")
    endif()
    # required arguments
    if(NOT DEFINED xc_PROJECT)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} requires: PROJECT")
    endif()
    set(PROJECT_FILENAME "${xc_PROJECT}.xcodeproj")

    if(NOT DEFINED xc_FRAMEWORK)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION} requires: FRAMEWORK")
    endif()
    set(FRAMEWORK_FILENAME "${xc_FRAMEWORK}.framework")

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
        COMMAND ${XCODEBUILD} -project ${PROJECT_FILENAME} -target ${xc_FRAMEWORK} -jobs ${VCPKG_CONCURRENCY} -configuration Debug ${xc_PARAMS}
        WORKING_DIRECTORY ${xc_WORKING_DIRECTORY}
        LOGNAME "${xc_LOGNAME}-${TARGET_TRIPLET}-dbg"
    )
    if(xc_COPY_AFTER_BUILD)
        file(COPY "${OUTPUT_DIR_DBG}/${FRAMEWORK_FILENAME}" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
    endif()

    message(STATUS "Building ${TARGET_TRIPLET}-rel")
    vcpkg_execute_required_process(
        COMMAND ${XCODEBUILD} -project ${PROJECT_FILENAME} -target ${xc_FRAMEWORK} -jobs ${VCPKG_CONCURRENCY} -configuration Release ${xc_PARAMS}
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
elseif(VCPKG_TARGET_IS_IOS)
    set(SDK iphoneos)
    if(VCPKG_TARGET_IS_SIMULATOR)
        set(SDK iphonesimulator)
    endif()
else()
    message(FATAL_ERROR "Unsupported target platform")
endif()

# generate xcodeproject: swift-nio-ssl.xcodeproj
find_program(SWIFT NAMES swift REQUIRED)
message(STATUS "Using swift: ${SWIFT}")
swiftpm_generatate_xcodeproj(LOGNAME "generate")

find_program(XCODEBUILD NAMES xcodebuild REQUIRED)
message(STATUS "Using xcodebuild: ${XCODEBUILD}")
message(STATUS "  -sdk ${SDK} -arch ${ARCH}")
if(DEFINED XCODEBUILD_PARAMS)
message(STATUS "  ${XCODEBUILD_PARAMS}")
endif()

# before build, record some project info for CI environment debugging
vcpkg_execute_required_process(
    COMMAND ${XCODEBUILD} -project swift-nio-ssl.xcodeproj -list
    WORKING_DIRECTORY ${SOURCE_PATH}
    LOGNAME "project-${TARGET_TRIPLET}"
)

# build some targets
xcodebuild_build_framework(PROJECT swift-nio-ssl FRAMEWORK CNIOBoringSSL
    PARAMS -sdk ${SDK} -arch ${ARCH} ${XCODEBUILD_PARAMS}
    LOGNAME "build1" COPY_AFTER_BUILD
)
xcodebuild_build_framework(PROJECT swift-nio-ssl FRAMEWORK CNIOBoringSSLShims
    PARAMS -sdk ${SDK} -arch ${ARCH} ${XCODEBUILD_PARAMS}
    LOGNAME "build2" COPY_AFTER_BUILD
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
