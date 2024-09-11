vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO intel/ARM_NEON_2_x86_SSE
    REF 504231850f206696faa58e3511e305a67fd4e565
    SHA512 f53b5863bb79d40a4ef9c56a8d6a602783a10b28a4609e83664faa6eed8321a744bc5e9252502e1feabd099e58ea5b9e2fe6823a60019974f657fd4c68037982
    PATCHES
        fix-cmake.patch
    HEAD_REF master
)

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME NEON_2_SSE CONFIG_PATH lib/cmake/NEON_2_SSE)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/lib"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
