vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO zlib-ng/zlib-ng
    REF 2.1.6
    SHA512 59ef586c09b9a63788475abfd6dd59ed602316b38f543f801bea802ff8bec8b55a89bee90375b8bbffa3bdebc7d92a00903f4b7c94cdc1a53a36e2e1fd71d13a
    HEAD_REF develop
    PATCHES
        fix-cmake.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        zlib-compat ZLIB_COMPAT # When OFF, "-ng" suffix will remain
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DSKIP_INSTALL_ALL=OFF
        -DSKIP_INSTALL_HEADERS=OFF
        -DSKIP_INSTALL_LIBRARIES=OFF
        -DSKIP_INSTALL_FILES=OFF
        -DZLIB_ENABLE_TESTS=OFF
        -DZLIBNG_ENABLE_TESTS=OFF
        -DWITH_NEW_STRATEGIES=ON
        -DWITH_NATIVE_INSTRUCTIONS=OFF # `-march=native` breaks `check_c_source_compiles`
    OPTIONS_DEBUG
        -DWITH_OPTIM=OFF
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig() # zlib-ng>=2.0
if("zlib-compat" IN_LIST FEATURES)
    vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/ZLIB PACKAGE_NAME ZLIB)
else()
    vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/zlib-ng PACKAGE_NAME zlib-ng)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share"
                    "${CURRENT_PACKAGES_DIR}/debug/include"
)
file(INSTALL "${SOURCE_PATH}/LICENSE.md"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright
)