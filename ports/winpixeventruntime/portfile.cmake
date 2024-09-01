vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY ONLY_DYNAMIC_CRT)
set(VCPKG_POLICY_MISMATCHED_NUMBER_OF_BINARIES enabled)

vcpkg_find_acquire_program(NUGET)

set(ENV{NUGET_PACKAGES} "${BUILDTREES_DIR}/nuget")

# https://devblogs.microsoft.com/pix/pix-2403/
# see https://www.nuget.org/packages/WinPixEventRuntime/
set(PACKAGE_NAME    "WinPixEventRuntime")
set(PACKAGE_VERSION "1.0.240308001")

file(REMOVE_RECURSE "${CURRENT_BUILDTREES_DIR}/${PACKAGE_NAME}")
vcpkg_execute_required_process(
    COMMAND ${NUGET} install "${PACKAGE_NAME}" -Version "${PACKAGE_VERSION}" -Verbosity detailed
                -OutputDirectory "${CURRENT_BUILDTREES_DIR}"
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
    LOGNAME install-nuget
)

get_filename_component(SOURCE_PATH "${CURRENT_BUILDTREES_DIR}/${PACKAGE_NAME}.${PACKAGE_VERSION}" ABSOLUTE)
if(VCPKG_TARGET_IS_WINDOWS)
    if(NOT ((VCPKG_TARGET_ARCHITECTURE STREQUAL "x64") OR (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")))
        message(WARNING "The architecture '${VCPKG_TARGET_ARCHITECTURE}' is not expected")
    endif()
else()
    message(FATAL_ERROR "The triplet '${TARGET_TRIPLET}' is not supported")
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    file(INSTALL "${SOURCE_PATH}/bin/${VCPKG_TARGET_ARCHITECTURE}/WinPixEventRuntime.lib"       DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    file(INSTALL "${SOURCE_PATH}/bin/${VCPKG_TARGET_ARCHITECTURE}/WinPixEventRuntime.dll"       DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
    file(INSTALL "${SOURCE_PATH}/bin/${VCPKG_TARGET_ARCHITECTURE}/WinPixEventRuntime_UAP.lib"   DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    file(INSTALL "${SOURCE_PATH}/bin/${VCPKG_TARGET_ARCHITECTURE}/WinPixEventRuntime_UAP.dll"   DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
else()
    message(FATAL_ERROR "The target platform is not supported")
endif()

file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

file(INSTALL "${SOURCE_PATH}/ThirdPartyNotices.txt"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/license.txt")
