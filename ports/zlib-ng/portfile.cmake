vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO zlib-ng/zlib-ng
    REF 2.0.6
    SHA512 4888f17160d0a87a9b349704047ae0d0dc57237a10e11adae09ace957afa9743cce5191db67cb082991421fc961ce68011199621034d2369c0e7724fad58b4c5
    HEAD_REF master
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        zlib-compat ZLIB_COMPAT # When OFF, "-ng" suffix will remain
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DZLIB_FULL_VERSION=2.0.6
        -DZLIB_ENABLE_TESTS=OFF
        -DWITH_NEW_STRATEGIES=ON
        -DWITH_NATIVE_INSTRUCTIONS=OFF # `-march=native` breaks `check_c_source_compiles`
    OPTIONS_DEBUG
        -DWITH_OPTIM=OFF
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig() # zlib-ng>=2.0

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share"
                    "${CURRENT_PACKAGES_DIR}/debug/include"
)
file(INSTALL "${SOURCE_PATH}/LICENSE.md"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright
)