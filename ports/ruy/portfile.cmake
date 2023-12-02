vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/ruy
    REF c04e5e52ae6b144f74ac032652e3c538bda15c9b
    SHA512 e25779a43ee5830d1294bcccbe1f8b3057971944820c050a51b55e4a46abada3800d6ea7fa8ad94e291f6f8de7179db2e75d2d1c23da5221ffd8d1cf1b463964
    HEAD_REF master
    PATCHES
        fix-cmake.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        -DRUY_MINIMAL_BUILD=ON
        -DRUY_ENABLE_INSTALL=ON
        -DRUY_FIND_CPUINFO=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/${PORT})

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include 
                    ${CURRENT_PACKAGES_DIR}/debug/share
)
file(INSTALL ${SOURCE_PATH}/LICENSE
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright
)
