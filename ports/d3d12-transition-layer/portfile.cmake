vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

# todo: MicrosoftTelemetry from https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/Telemetry/MicrosoftTelemetry.h

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/D3D12TranslationLayer
    REF 315ca769aeed49bb84f72a8d5551951ba092ccd8
    SHA512 960c1eaa6f497555c4655e03fc930d85dcf32557a412e4921d10018232a4cff660a3943afac18e6d4d0509956a06ff55f8bfeadc496e4219a3f1b70f983a7b57
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
