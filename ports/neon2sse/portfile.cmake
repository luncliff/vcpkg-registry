vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO intel/ARM_NEON_2_x86_SSE
    REF 6315d3c5007e6c209eb77abae4deece4978d8dbc
    SHA512 855a2477db4164ff872f5ccf6713b4814e1d39c3ec162bcb7a631efcecc412affa1fe4fbe5ea7a4b764980ea5c2bc736f5666975039d14137ce33167cce1c6b0
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
