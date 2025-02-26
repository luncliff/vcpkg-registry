vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/client
    REF 3d9424956ba14660f9447575928601d449919abd
    SHA512 53a19801bcabf579011ddd9f682cf49f2e2e472816d7ff6cb0790eb404c2b9b19ce9c22e71d0bda9f21f7211deab80b94d6401b6ddf62c1e7839fb88b01e4d88
    HEAD_REF main
    PATCHES
        fix-cmake.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        gpu   TRITON_ENABLE_GPU
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/src/c++"
    OPTIONS
        -DTRITON_MIN_CXX_STANDARD=17
        -DTRITON_USE_THIRD_PARTY=OFF
        -DTRITON_ENABLE_CC_HTTP=ON
        -DTRITON_ENABLE_CC_GRPC=ON
        -DTRITON_ENABLE_EXAMPLES=OFF
        -DTRITON_ENABLE_TESTS=OFF
        -DTRITON_ENABLE_ZLIB=OFF
        # -DTRITON_ENABLE_PERF_ANALYZER=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/TritonClient PACKAGE_NAME TritonClient)
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
