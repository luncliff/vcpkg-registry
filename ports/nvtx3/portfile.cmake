vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/NVTX
    REF v${VERSION}
    SHA512 5a665a06d6f8d3a8cf47c9d9c3d4d496aac78b89d06e3cd622b521bbcc4c4836d4f71c87508fde6cc7ae4a865804fffdaaca1047926cc8aeda2fb49730c86c39
    HEAD_REF release-v3
)

# header-only library. we don't need other configurations
set(VCPKG_BUILD_TYPE release)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/c"
    OPTIONS
        -DNVTX3_TARGETS_NOT_USING_IMPORTED=ON
        -DNVTX3_INSTALL=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/nvtx3")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/lib"
)
file(INSTALL "${SOURCE_PATH}/c/README.md" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
