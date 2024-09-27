vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

# todo: MicrosoftTelemetry from https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/Telemetry/MicrosoftTelemetry.h

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/D3D12TranslationLayer
    REF 36a736f3776b2a886599f1dd17b868cafdac5d7b
    SHA512 ded991cedcd001992bd9e61b4c36d3e5b9c576231b9c90c79dc7fdff4508d4ad68d68b4715301f4512dee0d7d5dcfad15946fc87919ba6466f039891eafda49d
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
