if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()
vcpkg_find_acquire_program(PKGCONFIG)
message(STATUS "Using pkgconfig: ${PKGCONFIG}")

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/angle
    REF 2d91f554ab55bd1bef6998ab4094f60ae3e7feb5
    SHA512 bf97418db1c5217fabe1a56def6f02c382bd4eeb7b24c639f83366dd0d6418c9dd29037dd4869ba368292f04fef39602b643bb9c5199a03993c7c7da89a98a6e
    HEAD_REF main
)

file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        "-DPKG_CONFIG_EXECUTABLE=${PKGCONFIG}"
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/${PORT})
vcpkg_copy_pdbs()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include"
                    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
