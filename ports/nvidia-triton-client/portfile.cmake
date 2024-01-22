
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/client
    REF 24c1ff7969e4f8f9e31a5c98237b6c1b5972bfca
    SHA512 11ccd99ac862cd102879a2491c3e679c3876d95dc294ace46e1f29ef2f74e1b1e8cb2df32d6e47841eb1e060d3e3a99fece036c5275cf84ed84e61ae233c552d
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
