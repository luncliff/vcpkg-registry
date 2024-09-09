vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/ruy
    REF c08ec529fc91722bde519628d9449258082eb847
    SHA512 de97886f07d5ca211d6a6106696448f14556fe1926b72b6722976d17519a9d78babfb8ec994b422304e50225b4f9d95c0d9e01afb2076de89eb480664d4eb03f
    PATCHES
        fix-cmake.patch
    HEAD_REF master
)

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        -DRUY_MINIMAL_BUILD=ON
        -DRUY_ENABLE_INSTALL=ON
        -DRUY_FIND_CPUINFO=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/${PORT}")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
