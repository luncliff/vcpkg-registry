vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO dtrugman/pfs
    REF "v${VERSION}"
    SHA512 786183672ba5e42acfb4399b5933c0ae8ad59862e44ac1187c6ed510abc0e85d79327cb200310c8be641947b29356559ec4388a157eb45d7d67891b06b0e258a
    HEAD_REF master
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_PARALLEL_CONFIGURE
    OPTIONS
        -Dpfs_BUILD_TESTS=OFF
        -Dpfs_BUILD_SAMPLES=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH bin PACKAGE_NAME pfs)
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/debug/include"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
