vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO SFML/SFML
    REF ${VERSION}
    SHA512 7fc3f91b84ba2353b4216c0d0a71fd15f7349b8e22630dd727fc98a1f8c295a69fe21f3e1e878413966662047280ed4f195b51ee3302061c3903aea4958a6999
    HEAD_REF master
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DSFML_BUILD_WINDOW=ON
        -DSFML_BUILD_GRAPHICS=ON
        -DSFML_BUILD_AUDIO=ON
        -DSFML_BUILD_NETWORK=ON
        -DSFML_USE_SYSTEM_DEPS=ON
        -DSFML_INSTALL_PKGCONFIG_FILES=ON
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/SFML)
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE 
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/license.md")
