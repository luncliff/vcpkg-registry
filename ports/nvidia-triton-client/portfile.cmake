
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/client
    REF 442915d806a9a6170f1ac138681a48200ec93899
    SHA512 63a29643d1bf46244cfb670c36f53fdafda17fb2e2365b9e6bd78088b7d83e3c69c4a2d28ef25f0cc6c9d522140b290574e53b33b2b00ddbf7a9179bf370fc92
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
        -DTRITON_ENABLE_PERF_ANALYZER=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/TritonClient PACKAGE_NAME TritonClient)
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
