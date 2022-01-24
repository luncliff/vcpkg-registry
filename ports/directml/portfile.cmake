
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY) # [ONLY_STATIC_CRT | ONLY_DYNAMIC_CRT]
vcpkg_find_acquire_program(NUGET)

set(PACKAGE_NAME    "Microsoft.AI.DirectML")
set(PACKAGE_VERSION "1.6.0")

file(REMOVE_RECURSE ${CURRENT_BUILDTREES_DIR}/${PACKAGE_NAME})
vcpkg_execute_required_process(
    COMMAND ${NUGET} install "${PACKAGE_NAME}" -Version "${PACKAGE_VERSION}" -Verbosity detailed
                -OutputDirectory "${CURRENT_BUILDTREES_DIR}"
    WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}
    LOGNAME install-nuget
)

get_filename_component(SOURCE_PATH ${CURRENT_BUILDTREES_DIR}/${PACKAGE_NAME}.${PACKAGE_VERSION} ABSOLUTE)
if(TARGET_TRIPLET STREQUAL x64-windows)
    set(BIN_FOLDER "x64-win")
elseif(TARGET_TRIPLET STREQUAL x86-windows)
    set(BIN_FOLDER "x86-win")
elseif(TARGET_TRIPLET STREQUAL arm64-windows)
    set(BIN_FOLDER "arm64-win")
elseif(TARGET_TRIPLET STREQUAL arm-windows)
    set(BIN_FOLDER "arm-win")
elseif(TARGET_TRIPLET STREQUAL x64-linux)
    set(BIN_FOLDER "x64-linux")
else()
    message(FATAL_ERROR "The triplet '${TARGET_TRIPLET}' is not supported")
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    file(INSTALL ${SOURCE_PATH}/${BIN_FOLDER}/DirectML.dll       DESTINATION ${CURRENT_PACKAGES_DIR}/bin)
    file(INSTALL ${SOURCE_PATH}/${BIN_FOLDER}/DirectML.pdb       DESTINATION ${CURRENT_PACKAGES_DIR}/bin)
    file(INSTALL ${SOURCE_PATH}/${BIN_FOLDER}/DirectML.lib       DESTINATION ${CURRENT_PACKAGES_DIR}/lib)
    file(INSTALL ${SOURCE_PATH}/${BIN_FOLDER}/DirectML.Debug.dll DESTINATION ${CURRENT_PACKAGES_DIR}/debug/bin)
    file(INSTALL ${SOURCE_PATH}/${BIN_FOLDER}/DirectML.Debug.pdb DESTINATION ${CURRENT_PACKAGES_DIR}/debug/bin)
    file(INSTALL ${SOURCE_PATH}/${BIN_FOLDER}/DirectML.lib       DESTINATION ${CURRENT_PACKAGES_DIR}/debug/lib)
elseif(VCPKG_TARGET_IS_LINUX)
    file(INSTALL ${SOURCE_PATH}/${BIN_FOLDER}/libdirectml.so     DESTINATION ${CURRENT_PACKAGES_DIR}/lib)
    file(INSTALL ${SOURCE_PATH}/${BIN_FOLDER}/libdirectml.so     DESTINATION ${CURRENT_PACKAGES_DIR}/debug/lib)
else()
    message(FATAL_ERROR "The target platform is not supported")
endif()

file(INSTALL ${SOURCE_PATH}/include DESTINATION ${CURRENT_PACKAGES_DIR}/include)

file(INSTALL ${SOURCE_PATH}/LICENSE.txt
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright
)
file(INSTALL ${SOURCE_PATH}/LICENSE-CODE.txt
             ${SOURCE_PATH}/README.md
             ${SOURCE_PATH}/ThirdPartyNotices.txt
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT}
)
