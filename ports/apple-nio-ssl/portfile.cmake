if(VCPKG_TARGET_IS_IOS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/swift-nio-ssl
    REF 2.23.0
    SHA512 a7d4478f3ebd8dd1ee78c71afef610c33b74fb1b38054ef352dccbc454b8c56b30158c63d20d8468fa17e3f688445814ea743b841bbac28b8639bc81cef86632
    HEAD_REF main
)
# To Do: use .patch instead of this...
# fix some part of Package.swift.
vcpkg_replace_string("${SOURCE_PATH}/Package.swift" "/* This target" "//")
vcpkg_replace_string("${SOURCE_PATH}/Package.swift" "MANGLE_END */" "//")
if(VCPKG_LIBRARY_LINKAGE STREQUAL dynamic)
    vcpkg_replace_string("${SOURCE_PATH}/Package.swift" "type: .static," "type: .dynamic,")
elseif(VCPKG_LIBRARY_LINKAGE STREQUAL dynamic)
    vcpkg_replace_string("${SOURCE_PATH}/Package.swift" "type: .dynamic," "type: .static,")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH NIO_SOURCE_PATH
    REPO apple/swift-nio
    REF 2.42.0
    SHA512 cea980fc5b0ea74314932c8986799233731c3bfba850fef4b1a11d613b7b58c0b3ddb0dc28a7a1b04ccc9a24bafb8709e7a6335792fb4e0acaad182c2158e4cc
    HEAD_REF main
)

# use source folder so `--editable` can take effect always
get_filename_component(CUSTOM_BUILDTREES_DIR "${SOURCE_PATH}" PATH)
# see vcpkg_extract_source_archive
if(NOT _VCPKG_EDITABLE)
    file(REMOVE_RECURSE "${SOURCE_PATH}/.build" "${SOURCE_PATH}/build")
endif()

# use symbolic link to prevent SwiftPM checkouts
set(ENV{SWIFTCI_USE_LOCAL_DEPS} "TRUE")
file(CREATE_LINK "${NIO_SOURCE_PATH}" "${CUSTOM_BUILDTREES_DIR}/swift-nio" SYMBOLIC)

# find required tools to build
find_program(SWIFT NAMES swift REQUIRED)
message(STATUS "Detected swift: ${SWIFT}")
find_program(XCODEBUILD NAMES xcodebuild REQUIRED)
message(STATUS "Detected xcodebuild: ${XCODEBUILD}")

message(STATUS "Generating Xcode project from Package.swift")
vcpkg_execute_required_process(
    COMMAND ${SWIFT} package generate-xcodeproj
    WORKING_DIRECTORY ${SOURCE_PATH}
    LOGNAME "generate-${TARGET_TRIPLET}"
)

message(STATUS "Recording project info")
vcpkg_execute_required_process(
    COMMAND ${XCODEBUILD} -project swift-nio-ssl.xcodeproj -list
    WORKING_DIRECTORY ${SOURCE_PATH}
    LOGNAME "info-${TARGET_TRIPLET}"
)

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(ARCH "arm64")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(ARCH "x86_64")
else()
    message(FATAL_ERROR "Unsupported architecture: ${VCPKG_TARGET_ARCHITECTURE}")
endif()

if(VCPKG_TARGET_IS_OSX)
    set(SDK macosx)
    set(OUTPUT_PATH_DBG ${SOURCE_PATH}/build/Debug)
    set(OUTPUT_PATH_REL ${SOURCE_PATH}/build/Release)
elseif(VCPKG_TARGET_IS_IOS)
    set(SDK iphoneos)
    if(VCPKG_TARGET_IS_SIMULATOR)
        set(SDK iphonesimulator)
        set(OUTPUT_PATH_DBG ${SOURCE_PATH}/build/Debug-iphonesimulator)
        set(OUTPUT_PATH_REL ${SOURCE_PATH}/build/Release-iphonesimulator)
    else()
        set(OUTPUT_PATH_DBG ${SOURCE_PATH}/build/Debug-iphoneos)
        set(OUTPUT_PATH_REL ${SOURCE_PATH}/build/Release-iphoneos)
    endif()
else()
    message(FATAL_ERROR "Unsupported target platform")
endif()

message(STATUS "Building ${TARGET_TRIPLET}-dbg")
vcpkg_execute_required_process(
    COMMAND ${XCODEBUILD} -project swift-nio-ssl.xcodeproj -target CNIOBoringSSL -jobs ${VCPKG_CONCURRENCY}
                -sdk ${SDK} -arch ${ARCH} -configuration Debug
    WORKING_DIRECTORY ${SOURCE_PATH}
    LOGNAME "build-${TARGET_TRIPLET}-dbg"
)
message(STATUS "Building ${TARGET_TRIPLET}-rel")
vcpkg_execute_required_process(
    COMMAND ${XCODEBUILD} -project swift-nio-ssl.xcodeproj -target CNIOBoringSSL -jobs ${VCPKG_CONCURRENCY}
                -sdk ${SDK} -arch ${ARCH} -configuration Release
    WORKING_DIRECTORY ${SOURCE_PATH}
    LOGNAME "build-${TARGET_TRIPLET}-rel"
)

set(OUT_FWK "CNIOBoringSSL.framework")

file(COPY ${OUTPUT_PATH_DBG}/${OUT_FWK} DESTINATION ${CURRENT_PACKAGES_DIR}/debug/lib)
file(COPY ${OUTPUT_PATH_REL}/${OUT_FWK} DESTINATION ${CURRENT_PACKAGES_DIR}/lib)

# install public/private headers
file(GLOB headers
    ${SOURCE_PATH}/Sources/CNIOBoringSSL/include/*.h
)
file(INSTALL ${headers} DESTINATION ${CURRENT_PACKAGES_DIR}/include/CNIOBoringSSL)

file(GLOB ssl_headers
    ${SOURCE_PATH}/Sources/CNIOBoringSSL/ssl/*.h
)
file(INSTALL ${ssl_headers} DESTINATION ${CURRENT_PACKAGES_DIR}/include/ssl)

file(GLOB crypto_headers
    ${SOURCE_PATH}/Sources/CNIOBoringSSL/crypto/*.h
)
file(INSTALL ${crypto_headers} DESTINATION ${CURRENT_PACKAGES_DIR}/include/crypto)


file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/lib/${OUT_FWK}/Versions/A/_CodeSignature"
)

file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
