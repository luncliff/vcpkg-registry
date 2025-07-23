vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO jerryscript-project/jerryscript
    REF "v${VERSION}"
    SHA512 cd9767143f3821311c81f1ead85ed75d0f98ea1aa8a6dd09cdd6e207b60d78180bee277ef20bbf77b7a87924132a51b96b72d8fb169a043ed7b79ba2d636b1ee
)

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC_RUNTIME)

# https://github.com/jerryscript-project/jerryscript/blob/v3.0.0/CMakeLists.txt
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DJERRY_EXT=ON
        -DJERRY_MATH=OFF
        -DJERRY_CMDLINE=OFF
        -DENABLE_STATIC_CRT=${USE_STATIC_RUNTIME}
        -DENABLE_LTO=OFF
        -DENABLE_STRIP=OFF
)
vcpkg_cmake_install()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
