vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO zlib-ng/zlib-ng
    REF 2.2.2
    SHA512 3cb3e97ee1d20e1f3cdf0efcdf55aee0e3a192f9a2ae781cd209b1d37620c48f2ada345fb1f4357315b1cb5e09b7ea5fcdfa2fd54f7b4ac5dcb6e73860000aad
    HEAD_REF 2.2.x
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
        -DWITH_GZFILEOP=ON
        -DWITH_NATIVE_INSTRUCTIONS=OFF # `-march=native` breaks `check_c_source_compiles`
    OPTIONS_DEBUG
        -DWITH_OPTIM=OFF
        -DWITH_INFLATE_STRICT=ON
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