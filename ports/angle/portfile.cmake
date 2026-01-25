# Force dynamic library on native Windows; allow static on other platforms (including Emscripten)
if(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_CROSSCOMPILING)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)
vcpkg_find_acquire_program(PKGCONFIG)
message(STATUS "Using pkgconfig: ${PKGCONFIG}")

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/angle
    REF 2d91f554ab55bd1bef6998ab4094f60ae3e7feb5
    SHA512 bf97418db1c5217fabe1a56def6f02c382bd4eeb7b24c639f83366dd0d6418c9dd29037dd4869ba368292f04fef39602b643bb9c5199a03993c7c7da89a98a6e
    HEAD_REF main
    PATCHES
        patches/fix-cxx17-erase.patch
)

file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")
file(COPY
    "${CMAKE_CURRENT_LIST_DIR}/compression_utils_portable.cpp"
    "${CMAKE_CURRENT_LIST_DIR}/compression_utils_portable.h"
    DESTINATION "${SOURCE_PATH}"
)
file(COPY
    "${CMAKE_CURRENT_LIST_DIR}/ANGLEShaderProgramVersion.h"
    "${CMAKE_CURRENT_LIST_DIR}/angle_commit.h"
    DESTINATION "${SOURCE_PATH}/src/common"
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        "-DPKG_CONFIG_EXECUTABLE=${PKGCONFIG}"
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/angle PACKAGE_NAME angle)
vcpkg_copy_pdbs()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include"
                    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
