vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

# todo: MicrosoftTelemetry from https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/Telemetry/MicrosoftTelemetry.h

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/D3D12TranslationLayer
    REF 1666438638012549dbaf959f921bca2aeff5c550
    SHA512 27e6ea47fab94df198b862b7dd6e97bc120ca873c4f18e639de6f69c0e4fecd4f46f9b742ec7aac106182b9c05903e71ae641cf8f83202f4cebf02ac2200b808
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
