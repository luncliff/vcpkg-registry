if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO dmlc/dlpack
    REF v1.0
    SHA512 bdf27bdb6d24db2da9155b9c78e62faf043e0aa4d54dba4cadac312c2b87533ae1b44ecebd462a764141297baa35884c1379902d655bab8a71fe65838c7b1e9b
    HEAD_REF main
    PATCHES
        fix-cmake.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBUILD_MOCK=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME "dlpack" CONFIG_PATH "lib/cmake/dlpack")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/lib"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
