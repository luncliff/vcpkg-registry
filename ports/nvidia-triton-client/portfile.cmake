vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/client
    REF 31c9421d4b0c2acbe9d9d214067ed74b7db4b6ae
    SHA512 bb349a0b7b05cc3cc27939b7fc65bf4f1bc648e271353994252ef79ec5dc5bba2fc12601af30b5c2d6afecac01b89cee0367b1ba0f140bf8562330394ee31957
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
