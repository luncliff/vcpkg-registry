vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

# todo: MicrosoftTelemetry from https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/Telemetry/MicrosoftTelemetry.h

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/D3D12TranslationLayer
    REF 283fe2eb00d75a3e4b59d935f486fffa4eac0b4d
    SHA512 837c8f520ffee924e11a843ab9353ed8d27ff54e2f7c746fe771e1d955637430fd351f6020594fa4b9340270d4b9c0472d37780bbe174444b05e0a48a65d7805
    PATCHES
        fix-vcpkg.patch
    HEAD_REF master
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    WINDOWS_USE_MSBUILD
    OPTIONS
        -DUSE_PIX=OFF
        -DHAS_WDK=OFF
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/include/D3D12TranslationLayer/pch.h"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
