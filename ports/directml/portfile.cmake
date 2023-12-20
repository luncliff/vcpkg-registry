vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY ONLY_DYNAMIC_CRT)
vcpkg_find_acquire_program(NUGET)

set(ENV{NUGET_PACKAGES} "${BUILDTREES_DIR}/nuget")

# see https://www.nuget.org/packages/Microsoft.AI.DirectML/
set(PACKAGE_NAME    "Microsoft.AI.DirectML")
set(PACKAGE_VERSION "1.13.0")

file(REMOVE_RECURSE "${CURRENT_BUILDTREES_DIR}/${PACKAGE_NAME}")
vcpkg_execute_required_process(
    COMMAND ${NUGET} install "${PACKAGE_NAME}" -Version "${PACKAGE_VERSION}" -Verbosity detailed
                -OutputDirectory "${CURRENT_BUILDTREES_DIR}"
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
    LOGNAME install-nuget
)

get_filename_component(SOURCE_PATH "${CURRENT_BUILDTREES_DIR}/${PACKAGE_NAME}.${PACKAGE_VERSION}" ABSOLUTE)
if(VCPKG_TARGET_IS_WINDOWS)
    # todo: x64-xbox?
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(TRIPLE "x64-win")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        set(TRIPLE "x86-win")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(TRIPLE "arm64-win")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        set(TRIPLE "arm-win")
    else()
        message(FATAL_ERROR "The architecture '${VCPKG_TARGET_ARCHITECTURE}' is not supported")
    endif()
elseif(VCPKG_TARGET_IS_LINUX)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(TRIPLE "x64-linux")
    else()
        message(FATAL_ERROR "The architecture '${VCPKG_TARGET_ARCHITECTURE}' is not supported")
    endif()
else()
    message(FATAL_ERROR "The triplet '${TARGET_TRIPLET}' is not supported")
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    file(INSTALL "${SOURCE_PATH}/bin/${TRIPLE}/DirectML.lib"        DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    file(INSTALL "${SOURCE_PATH}/bin/${TRIPLE}/DirectML.dll"        DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
    file(INSTALL "${SOURCE_PATH}/bin/${TRIPLE}/DirectML.pdb"        DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
    file(INSTALL "${SOURCE_PATH}/bin/${TRIPLE}/DirectML.Debug.dll"  DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
    file(INSTALL "${SOURCE_PATH}/bin/${TRIPLE}/DirectML.Debug.pdb"  DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
    # debug/release will use same copy
    file(INSTALL "${CURRENT_PACKAGES_DIR}/bin/" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/bin")
    file(INSTALL "${CURRENT_PACKAGES_DIR}/lib/" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
elseif(VCPKG_TARGET_IS_LINUX)
    file(INSTALL "${SOURCE_PATH}/bin/${TRIPLE}/libdirectml.so"  DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
else()
    message(FATAL_ERROR "The target platform is not supported")
endif()

file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
file(INSTALL "${SOURCE_PATH}/LICENSE-CODE.txt"
             "${SOURCE_PATH}/README.md"
             "${SOURCE_PATH}/ThirdPartyNotices.txt"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
