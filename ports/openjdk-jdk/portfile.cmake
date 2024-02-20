vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY) 

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO openjdk/jdk
    REF jdk-23+10
    SHA512 cccb0150c3662426a668b11f3d4b0652df53a421c39a42d88fc177f25f04df0ced6cb7ba5e47a44edb79d13d1677ca5877e066b2f98a7edac49ed7975fa61736
    HEAD_REF master
)

vcpkg_configure_make(
    SOURCE_PATH "${SOURCE_PATH}"
    AUTOCONFIG
    DISABLE_VERBOSE_FLAGS
    OPTIONS
        # --
    OPTIONS_RELEASE
        "--prefix=${CURRENT_PACKAGES_DIR}"
    OPTIONS_DEBUG
        "--prefix=${CURRENT_PACKAGES_DIR}/debug"
)

vcpkg_install_make()
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
