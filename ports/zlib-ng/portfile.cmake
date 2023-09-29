vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO zlib-ng/zlib-ng
    REF 2.0.7
    SHA512 1c19a62bb00727ac49049c299fb70060da95b5fafa448144ae4133372ec8c3da15cef6c1303485290f269b23c580696554ca0383dba3e1f9609f65c332981988
    HEAD_REF master
)
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    # list(APPEND ARCH_OPTIONS)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    # list(APPEND ARCH_OPTIONS)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    # list(APPEND ARCH_OPTIONS)
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        zlib-compat ZLIB_COMPAT # When OFF, "-ng" suffix will remain
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${ARCH_OPTIONS} ${FEATURE_OPTIONS}
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