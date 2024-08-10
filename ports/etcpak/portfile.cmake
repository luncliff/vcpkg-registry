vcpkg_check_linkage(ONLY_STATIC_LIBRARY) 

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO wolfpld/etcpak
    REF 2.0
    SHA512 0d765eddaa0899762f2c7d3cd37f5d0971b6e6275e32b81567ae58101ebc175d04a860851673950370ce410d1ef25d8f1c314c2582e14d8b874137e39ddb09c8
    HEAD_REF master
    PATCHES
        fix-meson.patch
        fix-sources.patch
)
file(REMOVE_RECURSE
    "${SOURCE_PATH}/lz4"
    "${SOURCE_PATH}/libpng"
    "${SOURCE_PATH}/subprojects"
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tracy   tracy_enable
        tool    build_tool
)
string(REPLACE "OFF" "false" FEATURE_OPTIONS "${FEATURE_OPTIONS}")
string(REPLACE "ON"  "true"  FEATURE_OPTIONS "${FEATURE_OPTIONS}")

vcpkg_configure_meson(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
)
vcpkg_install_meson()
if("tool" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES etcpak AUTO_CLEAN)
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
file(INSTALL "${SOURCE_PATH}/AUTHORS.txt"
             "${SOURCE_PATH}/README.md"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
