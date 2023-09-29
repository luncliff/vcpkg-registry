vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

# see https://developer.apple.com/library/archive/documentation/DeveloperTools/Reference/XcodeBuildSettingRef/1-Build_Setting_Reference/build_setting_ref.html
# see https://mgrebenets.github.io/xcode/2019/05/12/xcode-build-settings-in-depth
list(APPEND XCODEBUILD_PARAMS
    CODE_SIGNING_REQUIRED=NO
    CLANG_ENABLE_CODE_COVERAGE=NO
    # defines_module=yes
    # SWIFT_TREAT_WARNINGS_AS_ERRORS=NO
)
# if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
#     list(APPEND XCODEBUILD_PARAMS "MACH_O_TYPE=mh_dylib")
# elseif(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
#     list(APPEND XCODEBUILD_PARAMS "MACH_O_TYPE=staticlib")
# endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/swift-nio-ssl
    REF 2.25.0
    SHA512 5dec17e2d3a16c43185dd6f229aeca089fdcbea88cbdbdd26b401b7b5ccb1037d96dd008b679d36f3fa621f9569d7094b57e6bcb3b2e6b47048707bc1cd17114
    HEAD_REF main
    PATCHES
        fix-swiftpm.patch # SWIFTCI_USE_LOCAL_DEPS
)

vcpkg_from_github(
    OUT_SOURCE_PATH NIO_SOURCE_PATH
    REPO apple/swift-nio
    REF 2.54.0
    SHA512 664259d33e8c659d4544c0d96480ade35161dfbb9e8d5bc54771ae7ea26a90f90f52817e36b70fb88720881040a852dd447993e47a937bc53c51ba873c91388b
    HEAD_REF main
)

# see vcpkg_extract_source_archive
if(NOT _VCPKG_EDITABLE)
    file(REMOVE_RECURSE "${SOURCE_PATH}/.build" "${SOURCE_PATH}/build")
endif()

# create symbolic link to prevent swift-nio checkout
set(ENV{SWIFTCI_USE_LOCAL_DEPS} 1)
file(REMOVE_RECURSE "${CURRENT_BUILDTREES_DIR}/swift-nio")
file(CREATE_LINK "${NIO_SOURCE_PATH}" "${CURRENT_BUILDTREES_DIR}/swift-nio" SYMBOLIC)

# create build dir from sources
get_filename_component(BUILD_DIR_NAME "${SOURCE_PATH}" NAME)
file(REMOVE_RECURSE "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}")
file(COPY "${SOURCE_PATH}" DESTINATION "${CURRENT_BUILDTREES_DIR}")
file(RENAME "${CURRENT_BUILDTREES_DIR}/${BUILD_DIR_NAME}" "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}")

find_program(XCODEBUILD NAMES xcodebuild REQUIRED)
message(STATUS "Using xcodebuild: ${XCODEBUILD}")

# todo: consider VCPKG_TARGET_ARCHITECTURE
# todo: variant for "Mac Catalyst"
if(VCPKG_TARGET_IS_OSX)
    set(DESTINATION "generic/platform=macOS")
    set(PRODUCT_SUFFIX "")
elseif(VCPKG_TARGET_IS_IOS)
    set(DESTINATION "generic/platform=iOS")
    set(PRODUCT_SUFFIX "-iphoneos")
    if(VCPKG_TARGET_IS_IOS_SIMULATOR)
        set(DESTINATION "generic/platform=iOS Simulator")
        set(PRODUCT_SUFFIX "-iphonesimulator")
    endif()
else()
    message(FATAL_ERROR "The target platform is NOT supported")
endif()

# see Package.swift
set(SCHEME_NAME "CNIOBoringSSL")

message(STATUS "Building ${TARGET_TRIPLET}-dbg")
vcpkg_execute_required_process(
    COMMAND ${XCODEBUILD} -scheme ${SCHEME_NAME}
        -derivedDataPath DerivedData
        -destination "${DESTINATION}"
        -configuration Debug
        ${XCODEBUILD_PARAMS} build
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}"
    LOGNAME "build-${TARGET_TRIPLET}-dbg"
)

message(STATUS "Building ${TARGET_TRIPLET}-rel")
vcpkg_execute_required_process(
    COMMAND ${XCODEBUILD} -scheme ${SCHEME_NAME}
        -derivedDataPath DerivedData
        -destination "${DESTINATION}"
        -configuration Release
        ${XCODEBUILD_PARAMS} build
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}"
    LOGNAME "build-${TARGET_TRIPLET}-rel"
)

get_filename_component(DERIVED_DATA_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}/DerivedData" ABSOLUTE)
get_filename_component(FRAMEWORK_OUT_DBG "${DERIVED_DATA_DIR}/Build/Products/Debug${PRODUCT_SUFFIX}/PackageFrameworks" ABSOLUTE)
file(INSTALL "${FRAMEWORK_OUT_DBG}/CNIOBoringSSL.framework" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
get_filename_component(FRAMEWORK_OUT_REL "${DERIVED_DATA_DIR}/Build/Products/Release${PRODUCT_SUFFIX}/PackageFrameworks" ABSOLUTE)
file(INSTALL "${FRAMEWORK_OUT_REL}/CNIOBoringSSL.framework" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")

# install public/private headers
file(GLOB headers "${SOURCE_PATH}/Sources/CNIOBoringSSL/include/*.h")
file(INSTALL ${headers} DESTINATION "${CURRENT_PACKAGES_DIR}/include/CNIOBoringSSL")

# file(GLOB ssl_headers "${SOURCE_PATH}/Sources/CNIOBoringSSL/ssl/*.h")
# file(INSTALL ${ssl_headers} DESTINATION "${CURRENT_PACKAGES_DIR}/include/ssl")
# file(GLOB crypto_headers "${SOURCE_PATH}/Sources/CNIOBoringSSL/crypto/internal.h")
# file(INSTALL ${crypto_headers} DESTINATION "${CURRENT_PACKAGES_DIR}/include/crypto")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")