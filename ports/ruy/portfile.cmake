vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/ruy
    REF cd7b92695b5d3f0c9ff65b865c2a1e19b99d766d
    SHA512 01bf5b33cfa68e3643aa7ad8adcd392df692235bd11ffb8f1f073f5e67f5985d8abf814895406757f13f309de09cf42c54c3dc66591e5f79df4937399f343599
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
