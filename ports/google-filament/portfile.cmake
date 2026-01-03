# Filament is distributed as pre-compiled binary packages per platform
# Release v1.68.2 - asset mapping (grouped by platform)
#
# Web (wasm32-emscripten):
#  - filament-v1.68.2-web.tgz
#
# Android (arm64-android, x64-android):
#  - filament-v1.68.2-android.aar
#  - filament-v1.68.2-android-native.tgz
#  - filament-android-release-linux.tgz        # host-side android release for Linux
#  - filamat-v1.68.2-android.aar               # material tools for Android
#  - filament-utils-v1.68.2-android.aar
#  - gltfio-v1.68.2-android.aar
#  - filament-gltf-viewer-v1.68.2-android.apk  # sample APK
#
# macOS / iOS (x64-osx, arm64-osx, arm64-ios):
#  - filament-v1.68.2-mac.tgz
#  - filament-v1.68.2-ios.tgz
#
# Linux (x64-linux, arm64-linux):
#  - filament-v1.68.2-linux.tgz
#
# Notes:
#  - Android assets include multiple AARs and native tgz packages. For Android
#    targets this port should extract AAR contents and relocate headers/libs to
#    the vcpkg package layout. Focus on `arm64-android` (device) and
#    `x64-android` (AVD) triplets. Host-side tools (e.g., `filamat`) are in
#    the release and may be installed under `${CURRENT_PACKAGES_DIR}/tools`.
#  - Web builds use the web tgz which contains wasm/js artifacts.
#  - If a platform has no corresponding release asset, the platform is not supported.

set(VCPKG_POLICY_MISMATCHED_NUMBER_OF_BINARIES enabled)

# Determine which release asset to download based on the target platform
if(VCPKG_TARGET_IS_LINUX)
    if(NOT (VCPKG_TARGET_ARCHITECTURE STREQUAL "x86_64" OR VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64"))
        message(FATAL_ERROR "google-filament: Unsupported Linux architecture '${VCPKG_TARGET_ARCHITECTURE}'")
    endif()
    
    set(ASSET_NAME "filament-v${VERSION}-linux.tgz")
    set(ASSET_SHA512 "b74992b2535e0fa3528eeee6cca0d90e6d20db6834f972791dd2a7bd7685e25fddae25ae917c09911d31e1cef7f369003a7ec8033923c41813a9f82c36b2101bf")
    
elseif(VCPKG_TARGET_IS_OSX)
    if(NOT (VCPKG_TARGET_ARCHITECTURE STREQUAL "x86_64" OR VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64"))
        message(FATAL_ERROR "google-filament: Unsupported macOS architecture '${VCPKG_TARGET_ARCHITECTURE}'")
    endif()
    
    set(ASSET_NAME "filament-v${VERSION}-mac.tgz")
    set(ASSET_SHA512 "38860a2744e37807f98f7397c030ea31cf3a82ec282e82b162ce49eccc403b69be0e062d567ab5ed3511c04e57f535382b6ddccf198998d5756856f3593fb2e8")
    
else()
    message(FATAL_ERROR "google-filament: Unsupported platform")
endif()

# Download the release asset
vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/google/filament/releases/download/v${VERSION}/${ASSET_NAME}"
    FILENAME "${ASSET_NAME}"
    SHA512 "${ASSET_SHA512}"
)

# Extract the archive
vcpkg_extract_source_archive(SOURCE_PATH "${ARCHIVE}")

# The Filament release archives have a top-level directory named 'filament'
if(NOT EXISTS "${SOURCE_PATH}/filament")
    # Try alternate structure
    if(EXISTS "${SOURCE_PATH}/lib" OR EXISTS "${SOURCE_PATH}/include")
        # Files are directly in SOURCE_PATH
    else()
        # Look for nested filament directory
        file(GLOB TOP_DIRS LIST_DIRECTORIES true "${SOURCE_PATH}/*")
        list(LENGTH TOP_DIRS NUM_TOP_DIRS)
        if(NUM_TOP_DIRS EQUAL 1)
            list(GET TOP_DIRS 0 NESTED_DIR)
            if(IS_DIRECTORY "${NESTED_DIR}")
                set(SOURCE_PATH "${NESTED_DIR}")
            endif()
        endif()
    endif()
endif()

# Install headers
if(EXISTS "${SOURCE_PATH}/include")
    file(INSTALL "${SOURCE_PATH}/include/"
         DESTINATION "${CURRENT_PACKAGES_DIR}/include")
endif()

# Install libraries (lib directory contains all variants)
if(EXISTS "${SOURCE_PATH}/lib")
    # Copy release libs to lib directory
    file(GLOB RELEASE_LIBS "${SOURCE_PATH}/lib/*")
    foreach(LIB_FILE ${RELEASE_LIBS})
        if(NOT IS_DIRECTORY "${LIB_FILE}")
            file(INSTALL "${LIB_FILE}"
                 DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
        endif()
    endforeach()
    
    # No separate debug directory in Filament binaries
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
endif()

# Install binaries (if any)
if(EXISTS "${SOURCE_PATH}/bin")
    file(INSTALL "${SOURCE_PATH}/bin/"
         DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
endif()

# Install CMake config files (if they exist)
if(EXISTS "${SOURCE_PATH}/lib/cmake")
    file(INSTALL "${SOURCE_PATH}/lib/cmake"
         DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
endif()

# Install pkg-config files (if they exist)
if(EXISTS "${SOURCE_PATH}/lib/pkgconfig")
    file(INSTALL "${SOURCE_PATH}/lib/pkgconfig"
         DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
endif()

# Install tools (if any)
if(EXISTS "${SOURCE_PATH}/bin")
    file(GLOB TOOLS "${SOURCE_PATH}/bin/*")
    foreach(TOOL ${TOOLS})
        get_filename_component(TOOL_NAME "${TOOL}" NAME)
        # Copy tools for potential use
    endforeach()
endif()

# Remove unnecessary directories
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/share/man"
)

# Install license
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
