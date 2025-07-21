vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

# todo: MicrosoftTelemetry from https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/Telemetry/MicrosoftTelemetry.h

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/D3D12TranslationLayer
    REF 1be92fcd9a7a6c19b0796e445adba39d760f9f5a
    SHA512 200306582541989effe84f7bb3632840d24a443d9fd63707b65bdab2e6a565bfce084a878678f5cf77ea7fb76e06468306d53f7e344dff8a126e3071fff70a1f
    PATCHES
        fix-vcpkg.patch
    HEAD_REF master
)
file(REMOVE "${SOURCE_PATH}/external/d3dx12.h" "${SOURCE_PATH}/external/d3d12compatibility.h")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        pix  USE_PIX
        wdk  HAS_WDK
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    WINDOWS_USE_MSBUILD
    OPTIONS ${FEATURE_OPTIONS}
)
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/include/D3D12TranslationLayer/pch.h"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
