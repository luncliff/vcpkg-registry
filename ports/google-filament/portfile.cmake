# Filament is distributed as pre-compiled binary packages per platform
# Release v1.68.2 - asset mapping (grouped by platform)
#
# Web (wasm32-emscripten):
#  - filament-v1.68.2-web.tgz
#
# Android (arm64-android, x64-android):
#  - filament-v1.68.2-android-native.tgz    # C++/NDK native libraries
#
# macOS / iOS (x64-osx, arm64-osx, arm64-ios-simulator, arm64-ios):
#  - filament-v1.68.2-mac.tgz
#  - filament-v1.68.2-ios.tgz
#
# Linux (x64-linux, arm64-linux):
#  - filament-v1.68.2-linux.tgz
#
# References:
#  - https://learn.microsoft.com/en-us/vcpkg/maintainers/variables
#  - https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_extract_source_archive_ex
#  - https://learn.microsoft.com/en-us/vcpkg/maintainers/functions/vcpkg_copy_tools

set(VCPKG_POLICY_MISMATCHED_NUMBER_OF_BINARIES enabled)
set(VCPKG_BUILD_TYPE release)

# Select asset based on target platform and architecture
if(VCPKG_TARGET_IS_LINUX)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(ASSET_NAME "filament-v${VERSION}-linux.tgz")
        set(ASSET_SHA512 "b74992b2535e0fa3528eeee6cca0d90e6d20db6834f972791dd2a7bd7685e25fddae25ae917c0991
1d31e1cef7f36903a7ec8033923c41813a9f82c36b2101bf")
    else()
        message(FATAL_ERROR "Unsupported Linux architecture '${VCPKG_TARGET_ARCHITECTURE}' for Filament prebuilt binaries (only x64 available)")
    endif()

elseif(VCPKG_TARGET_IS_OSX)
    # macOS universal or x64 (both use same asset)
    set(ASSET_NAME "filament-v${VERSION}-mac.tgz")
    set(ASSET_SHA512 "38860a2744e37807f98f7397c030ea31cf3a82ec282e82b162ce49eccc403b69be0e062d567ab5ed35
11c04e57f535382b6ddccf198998d5756856f3593fb2e8")

elseif(VCPKG_TARGET_IS_IOS)
    # iOS (includes arm64-ios, arm64-ios-simulator)
    set(ASSET_NAME "filament-v${VERSION}-ios.tgz")
    set(ASSET_SHA512 "1cc2ddf347418ff4cb34a8e58b2e9fe1a8f95d55f7454547d709f73218eb769f3dc1391493d75d6d6
279b524952f8bc1a6d24b48059e45c44b6f479bb5260ba")

elseif(VCPKG_TARGET_IS_ANDROID)
    # Android (arm64-android for device, x64-android for emulator)
    # Filament ships platform-specific ABIs in the same archive
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(FILAMENT_ANDROID_ABI "arm64-v8a")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(FILAMENT_ANDROID_ABI "x86_64")
    else()
        message(FATAL_ERROR "Unsupported Android architecture '${VCPKG_TARGET_ARCHITECTURE}' (only arm64 and x64)")
    endif()
    set(ASSET_NAME "filament-v${VERSION}-android-native.tgz")
    set(ASSET_SHA512 "d8f8d7adfda0f69b4bd6dba97f526f368fd273b584ff83c8baa1856731c0d1fb151a146
c75ca2162b803d0b5c1ef1e080d989fa6b6283801774c604c6042b687")

elseif(VCPKG_TARGET_IS_EMSCRIPTEN)
    # WebAssembly/Emscripten
    set(ASSET_NAME "filament-v${VERSION}-web.tgz")
    set(ASSET_SHA512 "8db4f43d73f5f852d0bfe5b86aec36e47ef99a14d7f18e8f25bccbd96c9a146f4bd60b88290e17db91
c084fc912ce03da65547c9c838468f77a38cce9bee6d30")

elseif(VCPKG_TARGET_IS_WINDOWS)
    message(FATAL_ERROR "Upstream Filament does not provide prebuilt binaries for Windows; this port only supports linux|osx|ios|android|emscripten via prebuilt assets")

else()
    message(FATAL_ERROR "Unsupported target triplet '${TARGET_TRIPLET}' for google-filament")
endif()

# Download and extract the release asset
vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/google/filament/releases/download/v${VERSION}/${ASSET_NAME}"
    FILENAME "${ASSET_NAME}"
    SHA512 "${ASSET_SHA512}"
)
vcpkg_extract_source_archive_ex(OUT_SOURCE_PATH SOURCE_PATH ARCHIVE "${ARCHIVE}")

# Install headers
if(VCPKG_TARGET_IS_EMSCRIPTEN)
    # Web/Emscripten: may not have headers in the same structure; install if they exist
    if(EXISTS "${SOURCE_PATH}/include")
        file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
    endif()
else()
    # Native platforms: headers expected in standard location
    file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
endif()

# Install libraries
if(VCPKG_TARGET_IS_ANDROID)
    # Android: libs organized by ABI under lib/<abi>/
    if(EXISTS "${SOURCE_PATH}/lib/${FILAMENT_ANDROID_ABI}")
        file(INSTALL "${SOURCE_PATH}/lib/${FILAMENT_ANDROID_ABI}/" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    else()
        message(FATAL_ERROR "Expected Android library directory '${SOURCE_PATH}/lib/${FILAMENT_ANDROID_ABI}' not found")
    endif()
else()
    # Linux, macOS, iOS, Web: standard lib directory
    if(EXISTS "${SOURCE_PATH}/lib")
        file(INSTALL "${SOURCE_PATH}/lib/" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    endif()
endif()

# Install tools (host-side utilities)
if(EXISTS "${SOURCE_PATH}/bin")
    # Desktop platforms and Android release distributions typically include tools
    set(POTENTIAL_TOOLS matc cmgen filamesh mipgen matinfo roughness-prefilter imgui-usd-python)
    set(TOOLS_TO_INSTALL)
    foreach(tool ${POTENTIAL_TOOLS})
        if(EXISTS "${SOURCE_PATH}/bin/${tool}")
            list(APPEND TOOLS_TO_INSTALL ${tool})
        endif()
    endforeach()
    
    if(TOOLS_TO_INSTALL)
        vcpkg_copy_tools(TOOL_NAMES ${TOOLS_TO_INSTALL} AUTO_CLEAN)
    endif()
endif()

# Remove debug artifacts (release-only binary distribution)
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
)

# Install license and documentation
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
if(EXISTS "${SOURCE_PATH}/README.md")
    file(INSTALL "${SOURCE_PATH}/README.md" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
endif()
