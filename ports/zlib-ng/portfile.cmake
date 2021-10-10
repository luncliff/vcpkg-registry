vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO zlib-ng/zlib-ng
    REF 2.0.5
    SHA512 a643089a8189bf8bd24d679b84f07ae14932b4d88b88e94c44cca23350d6a9bbdaa411822d3651c2b0bf79f30c9f99514cc252cf9e9ab0b3a840540206466654
    HEAD_REF master
)

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        -DZLIB_COMPAT=OFF # "-ng" suffix will remain
        -DZLIB_FULL_VERSION=2.0.5
        -DZLIB_ENABLE_TESTS=OFF
        -DWITH_NEW_STRATEGIES=ON
        -DWITH_NATIVE_INSTRUCTIONS=OFF # `-march=native` breaks `check_c_source_compiles`
    OPTIONS_DEBUG
        -DWITH_OPTIM=OFF
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig() # zlib-ng>=2.0

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/share
                    ${CURRENT_PACKAGES_DIR}/debug/include
)
file(INSTALL ${SOURCE_PATH}/LICENSE.md
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright
)