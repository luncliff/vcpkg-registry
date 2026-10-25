vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

# todo: MicrosoftTelemetry from https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/Telemetry/MicrosoftTelemetry.h

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/D3D12TranslationLayer
    REF bc726e2af71b0060b879661df62172a9379d1f43
    SHA512 123f51c079088d0176486b02101c4e58ddd6133dfacae6271bbd7918dbff22f1657520f89c6e4b83762d71f95c715bc560bebc31bb93575b5a20c4cbbee28be4
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
