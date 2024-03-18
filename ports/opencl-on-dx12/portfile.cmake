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
    REF 9e46984446ee30c9ac8a45911aa3e57798246b9f
    SHA512 0e0e895fb61341e53f2010b697b527b7fa6b6a0676158672e521ac14016fa258a988dcb1ea012a7dd557915843c0bd31b0b94a589fa3c2a1bedb919ef4b189cb
    PATCHES
        fix-vcpkg.patch
    HEAD_REF master
)
file(COPY "${MS_TELEMETRY_H_PATH}" DESTINATION "${SOURCE_PATH}/external")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        test    BUILD_TESTS
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    WINDOWS_USE_MSBUILD
    OPTIONS
        ${FEATURE_OPTIONS}
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()

if("test" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES openclon12test AUTO_CLEAN)
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
file(INSTALL "${SOURCE_PATH}/README.md" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
