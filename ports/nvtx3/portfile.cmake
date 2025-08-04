vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/NVTX
    REF v${VERSION}
    SHA512 b65eb392f2fcf4a96fef84932cf61ceb85ae8a424e1128e77adde1e0452291d5e3eacd8bc0354f8878551ede0070dc0881406a4ffac1f3b13d2f7e56f4e0c41a
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
