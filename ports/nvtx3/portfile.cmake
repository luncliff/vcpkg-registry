vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/NVTX
    REF v${VERSION}
    SHA512 005bd1b060dc860f2270703d2b2bc12a6f80f4c2209e5598b5c19f745a3ca3f11f6808b211c2c10360a4ad2afed5a7e8531974591a8af9bde16b3e672405adbb
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
