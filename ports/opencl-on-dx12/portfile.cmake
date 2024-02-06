vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

# note: The URL is using 'master' branch. This is intended, so the port can detect some changes...
vcpkg_download_distfile(MS_TELEMETRY_H_PATH
    URLS "https://raw.githubusercontent.com/microsoft/winget-cli/master/src/AppInstallerSharedLib/Public/Telemetry/MicrosoftTelemetry.h"
    FILENAME MicrosoftTelemetry.h
    SHA512 33d229ee1e7eb9d176629d94eaa24a4ec1deb384a8b80a84834b5ca58bd0bf814dfd6051e29909e52cc293587c3edcfcf307873c43ec5bd8abb84eafa929dfd9
)
# file(INSTALL "${MS_TELEMETRY_H_PATH}" DESTINATION "${CURRENT_PACKAGES_DIR}/include/Telemetry")

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/OpenCLOn12
    REF b9cef1443007ed3cd4e39a03666a539f91e159e5
    SHA512 13aa2abe8ff0e3f14ed481bd45d8741d0783a40094ea1e70280414751f40784b4c82b9da60224bda51bf3d5c491b4471242118bc7ecf42b6497a55e9276afde7
    PATCHES
        fix-vcpkg.patch
    HEAD_REF master
)
file(COPY "${MS_TELEMETRY_H_PATH}" DESTINATION "${SOURCE_PATH}/external")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    WINDOWS_USE_MSBUILD
    OPTIONS
        -DBUILD_TESTS=OFF
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
file(INSTALL "${SOURCE_PATH}/README.md" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
