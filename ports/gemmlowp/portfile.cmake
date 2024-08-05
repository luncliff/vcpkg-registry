vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/gemmlowp
    REF 16e8662c34917be0065110bfcd9cc27d30f52fdf
    SHA512 d020c49c830f35e2568c3829d9b746285c835d3688fa77a7f08faa1bbe51e2e0fad34d5f4336f7c3fb86bc8a0afc869f34ced5464f7b3a120f3d0d34eb485ba1
    HEAD_REF master
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/contrib"
    OPTIONS
        -DBUILD_TESTING=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
