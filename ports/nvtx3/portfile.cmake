vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/NVTX
    REF v${VERSION}
    SHA512 506ab2c2b47caf63c53554b1ce219db5ba0d79626e1ca043479ac6f7332b5ce7ba89bbb4edeb17b4c98d9125b80b716d64ea2df15596310cfc0c1c129776b18a
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
