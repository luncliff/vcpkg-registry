vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/ruy
    REF 1e6e50872655a73b5250f954d7b9da9a87292fd3
    SHA512 6bb55aa485a07bd7ec739abe5a4745361e8376f0cfe92ee013b7a7d9e79437ee52213f79c84c50749738ea9f308d977777dc1ff7bc0cf166d0535a357a2f59c8
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
